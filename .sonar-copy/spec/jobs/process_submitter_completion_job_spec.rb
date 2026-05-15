# frozen_string_literal: true

RSpec.describe ProcessSubmitterCompletionJob do
  let(:account) { create(:account) }
  let(:user) { create(:user, account:) }
  let(:template) { create(:template, account:, author: user) }
  let(:submission) { create(:submission, template:, created_by_user: user) }
  let(:submitter) { create(:submitter, submission:, uuid: SecureRandom.uuid, completed_at: Time.current) }

  before do
    create(:encrypted_config, key: EncryptedConfig::ESIGN_CERTS_KEY,
                              value: GenerateCertificate.call.transform_values(&:to_pem))
  end

  describe '#perform' do
    before do
      allow(Submissions::EnsureResultGenerated).to receive(:call)
      allow(Submissions::EnsureAuditGenerated).to receive(:call)
      allow(Submissions::EnsureCombinedGenerated).to receive(:call)
    end

    it 'creates a completed submitter' do
      expect do
        described_class.new.perform('submitter_id' => submitter.id)
      end.to change(CompletedSubmitter, :count).by(1)

      completed_submitter = CompletedSubmitter.last
      submitter.reload

      expect(completed_submitter.submitter_id).to eq(submitter.id)
      expect(completed_submitter.submission_id).to eq(submitter.submission_id)
      expect(completed_submitter.account_id).to eq(submitter.submission.account_id)
      expect(completed_submitter.template_id).to eq(submitter.submission.template_id)
      expect(completed_submitter.source).to eq(submitter.submission.source)
    end

    it 'invokes completed documents creation' do
      job = described_class.new
      allow(job).to receive(:create_completed_documents!).and_call_original

      job.perform('submitter_id' => submitter.id)

      expect(job).to have_received(:create_completed_documents!).with(submitter)
    end

    it 'raises an error if the submitter is not found' do
      expect do
        described_class.new.perform('submitter_id' => 'invalid_id')
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe '#enqueue_completed_webhooks' do
    it 'enqueues form completed webhook and submission completed when all are completed' do
      webhook1 = double('webhook1', id: 1, events: [ProcessSubmitterCompletionJob::FORM_COMPLETED_EVENT])
      webhook2 = double('webhook2', id: 2, events: [ProcessSubmitterCompletionJob::SUBMISSION_COMPLETED_EVENT])
      allow(WebhookUrls).to receive(:for_account_id).and_return([webhook1, webhook2])
      allow(SendFormCompletedWebhookRequestJob).to receive(:perform_async)
      allow(SendSubmissionCompletedWebhookRequestJob).to receive(:perform_async)

      described_class.new.enqueue_completed_webhooks(submitter, is_all_completed: true)

      expect(SendFormCompletedWebhookRequestJob).to have_received(:perform_async).with(
        hash_including('submitter_id' => submitter.id, 'webhook_url_id' => 1, 'event_uuid' => kind_of(String))
      )
      expect(SendSubmissionCompletedWebhookRequestJob).to have_received(:perform_async).with(
        hash_including('submission_id' => submitter.submission_id, 'webhook_url_id' => 2, 'event_uuid' => kind_of(String))
      )
    end
  end

  describe '#create_completed_documents!' do
    it 'creates completed documents only when sha256 metadata is present' do
      with_sha = double('attachment1', metadata: { 'sha256' => 'abc' })
      without_sha = double('attachment2', metadata: { 'sha256' => nil })
      submitter_double = double('submitter', id: 10, documents: [with_sha, without_sha])
      allow(CompletedDocument).to receive(:find_or_create_by!)

      described_class.new.create_completed_documents!(submitter_double)

      expect(CompletedDocument).to have_received(:find_or_create_by!).with(sha256: 'abc', submitter_id: 10).once
    end
  end

  describe '#create_completed_submitter!' do
    it 'returns existing completed_submitter when already persisted' do
      existing = double('existing', persisted?: true)
      allow(CompletedSubmitter).to receive(:find_or_initialize_by).and_return(existing)

      result = described_class.new.create_completed_submitter!(submitter)

      expect(result).to eq(existing)
    end

    it 'sets verification_method to kba when complete_kba event exists' do
      completed_submitter = double('completed_submitter', persisted?: false)
      events_relation = double('events_relation')
      kba_event = double('kba_event', event_type: 'complete_kba', data: {})
      sms_event = double('sms_event', event_type: 'send_sms', data: { 'segments' => 2 })
      submission_double = double('submission', account_id: 1, template_id: 2, source: 'link')

      allow(CompletedSubmitter).to receive(:find_or_initialize_by).and_return(completed_submitter)
      allow(submitter).to receive(:submission).and_return(submission_double)
      allow(submitter).to receive(:submission_events).and_return(events_relation)
      allow(events_relation).to receive(:where).and_return([kba_event, sms_event])
      allow(CompletedSubmitter).to receive(:exists?).and_return(false)
      allow(completed_submitter).to receive(:assign_attributes)
      allow(completed_submitter).to receive(:save!)

      described_class.new.create_completed_submitter!(submitter)

      expect(completed_submitter).to have_received(:assign_attributes).with(hash_including(
        verification_method: 'kba',
        sms_count: 2
      ))
    end
  end

  describe '#build_bcc_addresses' do
    it 'extracts emails from submission bcc_completed preference first' do
      submission_double = double('submission',
                                 preferences: { 'bcc_completed' => 'a@example.com, b@example.com' },
                                 template: nil,
                                 account: double('account', account_configs: double('configs')))
      allow(submission_double.account.account_configs).to receive(:find_by).and_return(nil)

      result = described_class.new.build_bcc_addresses(submission_double)

      expect(result).to include('a@example.com', 'b@example.com')
    end
  end

  describe '#maybe_enqueue_copy_emails' do
    it 'enqueues one email per recipient when bcc_recipients is true' do
      recipients = [
        double('r1', preferences: {}, completed_at: 1.hour.ago, email?: true, friendly_name: 'A <a@example.com>'),
        double('r2', preferences: {}, completed_at: Time.current, email?: true, friendly_name: 'B <b@example.com>')
      ]
      submission_double = double('submission', submitters: recipients)
      template_double = double('template', preferences: {})
      submitter_double = double('submitter', template: template_double, account: double('account'),
                                             submission: submission_double)
      configs = double('configs', value: { 'enabled' => true, 'bcc_recipients' => true })
      mail = double('mail', deliver_later!: true)

      allow(AccountConfigs).to receive(:find_or_initialize_for_key).and_return(configs)
      allow(SubmitterMailer).to receive(:documents_copy_email).and_return(mail)

      described_class.new.maybe_enqueue_copy_emails(submitter_double)

      expect(SubmitterMailer).to have_received(:documents_copy_email).with(submitter_double, to: 'A <a@example.com>')
      expect(SubmitterMailer).to have_received(:documents_copy_email).with(submitter_double, to: 'B <b@example.com>')
    end

    it 'returns early when template disables copy emails' do
      template_double = double('template', preferences: { 'documents_copy_email_enabled' => false })
      submitter_double = double('submitter', template: template_double)

      allow(AccountConfigs).to receive(:find_or_initialize_for_key)

      described_class.new.maybe_enqueue_copy_emails(submitter_double)

      expect(AccountConfigs).not_to have_received(:find_or_initialize_for_key)
    end

    it 'returns early when account config disabled is false' do
      template_double = double('template', preferences: {})
      submission_double = double('submission')
      submitter_double = double('submitter', template: template_double, submission: submission_double, account: double('account'))
      configs = double('configs', value: { 'enabled' => false })

      allow(AccountConfigs).to receive(:find_or_initialize_for_key).and_return(configs)
      allow(SubmitterMailer).to receive(:documents_copy_email)

      described_class.new.maybe_enqueue_copy_emails(submitter_double)

      expect(SubmitterMailer).not_to have_received(:documents_copy_email)
    end

    it 'sends one combined copy email when bcc_recipients is false' do
      recipients = [
        double('r1', preferences: {}, completed_at: 1.hour.ago, email?: true, friendly_name: 'A <a@example.com>'),
        double('r2', preferences: {}, completed_at: Time.current, email?: true, friendly_name: 'B <b@example.com>')
      ]
      submission_double = double('submission', submitters: recipients)
      template_double = double('template', preferences: {})
      submitter_double = double('submitter', template: template_double, account: double('account'), submission: submission_double)
      configs = double('configs', value: { 'enabled' => true, 'bcc_recipients' => false })
      mail = double('mail', deliver_later!: true)

      allow(AccountConfigs).to receive(:find_or_initialize_for_key).and_return(configs)
      allow(SubmitterMailer).to receive(:documents_copy_email).and_return(mail)

      described_class.new.maybe_enqueue_copy_emails(submitter_double)

      expect(SubmitterMailer).to have_received(:documents_copy_email).with(
        submitter_double,
        to: 'A <a@example.com>, B <b@example.com>'
      )
      expect(mail).to have_received(:deliver_later!)
    end
  end

  describe '#enqueue_next_submitter_request_notification' do
    it 'sends request to next pending submitter in preserved order' do
      current = double('current', uuid: 'u1', completed_at?: true, completed_at: Time.current, sent_at: Time.current)
      next_submitter = double('next', uuid: 'u2', completed_at?: false, completed_at: nil, sent_at: nil)
      submission_double = double(
        'submission',
        template_submitters: [{ 'uuid' => 'u1' }, { 'uuid' => 'u2' }],
        submitters: [current, next_submitter]
      )
      submitter_double = double('submitter', uuid: 'u1', submission: submission_double)
      allow(Submitters).to receive(:send_signature_requests)

      described_class.new.enqueue_next_submitter_request_notification(submitter_double)

      expect(Submitters).to have_received(:send_signature_requests).with([next_submitter])
    end

    it 'handles grouped order flow and sends next group only when current group completed' do
      current_a = double('current_a', uuid: 'u1', completed_at?: true, completed_at: Time.current, sent_at: Time.current)
      current_b = double('current_b', uuid: 'u2', completed_at?: true, completed_at: Time.current, sent_at: Time.current)
      next_submitter = double('next', uuid: 'u3', completed_at?: false, completed_at: nil, sent_at: nil)

      submission_double = double(
        'submission',
        template_submitters: [
          { 'uuid' => 'u1', 'order' => 1 },
          { 'uuid' => 'u2', 'order' => 1 },
          { 'uuid' => 'u3', 'order' => 2 }
        ],
        submitters: [current_a, current_b, next_submitter]
      )
      submitter_double = double('submitter', uuid: 'u1', submission: submission_double)
      allow(Submitters).to receive(:send_signature_requests)

      described_class.new.enqueue_next_submitter_request_notification(submitter_double)

      expect(Submitters).to have_received(:send_signature_requests).with([next_submitter])
    end
  end
end
