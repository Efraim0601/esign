# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SendSubmitterReminderEmailJob do
  describe '#perform' do
    it 'returns when submitter is not found' do
      allow(Submitter).to receive(:find_by).with(id: 42).and_return(nil)

      expect(described_class.new.perform('submitter_id' => 42, 'duration_key' => '1d')).to be_nil
    end

    it 'sends reminder email, records event, and enqueues reminded webhooks' do
      account = double('account')
      submission = double('submission', archived_at?: false)
      submitter = double('submitter', id: 4, account: account, account_id: 12,
                                      completed_at?: false, declined_at?: false, sent_at: Time.current,
                                      submission: submission, template: nil)
      mail = double('mail')
      webhook = double('webhook', id: 77)

      allow(Submitter).to receive(:find_by).with(id: 4).and_return(submitter)
      allow(Accounts).to receive(:can_send_invitation_emails?).with(account).and_return(true)
      allow(AccountConfigs).to receive(:submitter_reminder_offsets).with(account).and_return({ '1d' => 3600 })
      allow(SubmissionEvent).to receive(:exists?).and_return(false)
      allow(SubmitterMailer).to receive(:invitation_reminder_email).with(submitter).and_return(mail)
      allow(Submitters::ValidateSending).to receive(:call).with(submitter, mail)
      allow(mail).to receive(:deliver_now!)
      allow(SubmissionEvent).to receive(:create!)
      allow(WebhookUrls).to receive(:for_account_id).with(12, ['form.reminded']).and_return([webhook])
      allow(SecureRandom).to receive(:uuid).and_return('uuid-1')
      allow(SendFormRemindedWebhookRequestJob).to receive(:perform_async)

      described_class.new.perform('submitter_id' => 4, 'duration_key' => '1d')

      expect(mail).to have_received(:deliver_now!)
      expect(SubmissionEvent).to have_received(:create!).with(hash_including(event_type: 'send_reminder_email'))
      expect(SendFormRemindedWebhookRequestJob).to have_received(:perform_async).with(hash_including(
        'submitter_id' => 4,
        'webhook_url_id' => 77,
        'event_uuid' => 'uuid-1',
        'duration_key' => '1d'
      ))
    end
  end

  describe '#reminder_still_configured?' do
    it 'returns false when duration key is no longer configured' do
      account = double('account')
      submitter = double('submitter', account: account)
      allow(AccountConfigs).to receive(:submitter_reminder_offsets).with(account).and_return({ '2d' => 7200 })

      expect(described_class.new.reminder_still_configured?(submitter, '1d')).to be(false)
    end
  end
end
