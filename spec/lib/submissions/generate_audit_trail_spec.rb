# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submissions::GenerateAuditTrail do
  describe '.build_audit_trail (integration with real PDF)' do
    let(:account) { create(:account) }
    let(:author) { create(:user, account:) }
    let(:template) do
      create(:template, account:, author:,
                        only_field_types: %w[text date checkbox signature number],
                        attachment_count: 1)
    end
    let(:submission) { create(:submission, template:, created_by_user: author) }
    let(:submitter) do
      submission.submitters.create!(
        account_id: submission.account_id,
        uuid: template.submitters.first['uuid'],
        email: 'completed@example.test',
        name: 'Audit Tester',
        completed_at: Time.current,
        ip: '127.0.0.1',
        ua: 'TestUA/1.0',
        opened_at: 1.minute.ago,
        sent_at: 5.minutes.ago,
        values: template.fields.each_with_object({}) do |field, acc|
          acc[field['uuid']] =
            case field['type']
            when 'text' then 'Hello'
            when 'date' then '2026-05-13'
            when 'checkbox' then true
            when 'number' then 42
            end
        end.compact
      )
    end

    before do
      # Skip filesystem-dependent / TLS heavy paths
      allow(Accounts).to receive(:load_signing_pkcs).and_return(nil)
      allow(Accounts).to receive(:load_timeserver_url).and_return(nil)
    end

    it 'renders an audit-trail PDF document from a completed submission' do
      submitter # ensure created

      doc = described_class.build_audit_trail(submission)

      expect(doc).to be_a(HexaPDF::Document)
      expect(doc.pages.count).to be >= 1
    end

    it 'renders audit trail with a French-locale account' do
      submitter
      account.update!(locale: 'fr-FR')

      doc = described_class.build_audit_trail(submission)

      expect(doc).to be_a(HexaPDF::Document)
    end

    it 'renders audit trail when source is a shared link' do
      submitter
      submission.update!(source: 'link')

      doc = described_class.build_audit_trail(submission)

      expect(doc).to be_a(HexaPDF::Document)
    end

    it 'renders audit trail with WITH_AUDIT_VALUES enabled by default' do
      submitter
      account.account_configs.create!(key: AccountConfig::WITH_AUDIT_VALUES_KEY, value: true)

      doc = described_class.build_audit_trail(submission)

      expect(doc).to be_a(HexaPDF::Document)
    end

    it 'renders audit trail with WITH_AUDIT_SENDER config enabled' do
      submitter
      account.account_configs.create!(key: AccountConfig::WITH_AUDIT_SENDER_KEY, value: true)

      doc = described_class.build_audit_trail(submission)

      expect(doc).to be_a(HexaPDF::Document)
    end

    it 'renders audit trail with submitter timezone preference enabled' do
      submitter
      submitter.update!(timezone: 'Europe/Paris')
      account.account_configs.create!(key: AccountConfig::WITH_SUBMITTER_TIMEZONE_KEY, value: true)

      doc = described_class.build_audit_trail(submission)

      expect(doc).to be_a(HexaPDF::Document)
    end

    it 'renders audit trail with WITH_SIGNATURE_ID disabled (no doc-id footer)' do
      submitter
      account.account_configs.create!(key: AccountConfig::WITH_SIGNATURE_ID, value: false)

      doc = described_class.build_audit_trail(submission)

      expect(doc).to be_a(HexaPDF::Document)
    end

    it 'renders audit trail with click_email and complete_form events' do
      submitter
      create(:submission_event, submission:, submitter:, event_type: 'click_email')
      create(:submission_event, submission:, submitter:, event_type: 'complete_form')

      doc = described_class.build_audit_trail(submission)

      expect(doc).to be_a(HexaPDF::Document)
    end

    it 'renders audit trail with email_verified event (phone-2fa shows verified)' do
      submitter
      create(:submission_event, submission:, submitter:, event_type: 'email_verified')

      doc = described_class.build_audit_trail(submission)

      expect(doc).to be_a(HexaPDF::Document)
    end
  end


  describe '.call' do
    it 'writes unsigned audit trail when no signing cert is configured' do
      info = {}
      trailer = double('trailer', info: info)
      document = double('document', trailer: trailer)
      blob = double('blob')
      account = double('account', locale: 'en')
      last_submitter = double('submitter', metadata: {}, completed_at: Time.current)
      submission = double('submission', name: 'S1', template: double('template', name: 'T1'), account: account,
                                        submitters: [last_submitter])

      allow(described_class).to receive(:build_audit_trail).with(submission).and_return(document)
      allow(Accounts).to receive(:load_signing_pkcs).with(account).and_return(nil)
      allow(Accounts).to receive(:load_timeserver_url).with(account).and_return(nil)
      allow(document).to receive(:write)
      allow(ActiveStorage::Blob).to receive(:create_and_upload!).and_return(blob)
      allow(ActiveStorage::Attachment).to receive(:create!)

      described_class.call(submission)

      expect(document).to have_received(:write).with(instance_of(StringIO))
      expect(ActiveStorage::Attachment).to have_received(:create!).with(hash_including(blob: blob, record: submission))
      expect(info[:Creator]).to include(Docuseal.product_name)
    end

    it 'signs audit trail when signing certificate is configured' do
      info = {}
      trailer = double('trailer', info: info)
      document = double('document', trailer: trailer)
      blob = double('blob')
      account = double('account', locale: 'en')
      last_submitter = double('submitter', metadata: {}, completed_at: Time.current)
      submission = double('submission', name: 'S1', template: double('template', name: 'T1'), account: account,
                                        submitters: [last_submitter])
      pkcs = double('pkcs')
      sign_params = { certificate: 'cert' }

      allow(described_class).to receive(:build_audit_trail).with(submission).and_return(document)
      allow(Accounts).to receive(:load_signing_pkcs).with(account).and_return(pkcs)
      allow(Accounts).to receive(:load_timeserver_url).with(account).and_return('https://tsa.example')
      allow(Submissions::GenerateResultAttachments).to receive(:build_signing_params)
        .with(last_submitter, pkcs, 'https://tsa.example').and_return(sign_params)
      allow(Submissions::GenerateResultAttachments).to receive(:maybe_enable_ltv)
      allow(document).to receive(:sign)
      allow(ActiveStorage::Blob).to receive(:create_and_upload!).and_return(blob)
      allow(ActiveStorage::Attachment).to receive(:create!)

      described_class.call(submission)

      expect(document).to have_received(:sign).with(instance_of(StringIO), hash_including(certificate: 'cert'))
      expect(Submissions::GenerateResultAttachments).to have_received(:maybe_enable_ltv)
    end
  end

  describe '.sign_reason' do
    it 'returns a stable signature reason' do
      expect(described_class.sign_reason).to eq('Signed with FirstSign')
    end
  end

  describe '.show_verify?' do
    it 'hides verify links for embed/api and shows for other sources' do
      expect(described_class.show_verify?(double('submission', source: 'embed'))).to be(false)
      expect(described_class.show_verify?(double('submission', source: 'api'))).to be(false)
      expect(described_class.show_verify?(double('submission', source: 'web'))).to be(true)
    end
  end

  describe '.maybe_add_background' do
    it 'is a no-op helper' do
      expect(described_class.maybe_add_background(double('canvas'), double('submission'), :A4)).to be_nil
    end
  end

  describe '.add_logo' do
    it 'writes logo image and branded text' do
      column = double('column')

      allow(column).to receive(:image)
      allow(column).to receive(:formatted_text)
      allow(PdfIcons).to receive(:logo_io).and_return(StringIO.new('png'))

      described_class.add_logo(column)

      expect(column).to have_received(:image)
      expect(column).to have_received(:formatted_text).with(
        array_including(hash_including(text: 'FirstSign')),
        hash_including(font_size: 20)
      )
    end
  end

  describe '.select_attachments' do
    it 'filters out image result attachments when many source images exist' do
      original_1 = double('orig1', uuid: 'o1', image?: true)
      original_2 = double('orig2', uuid: 'o2', image?: true)
      original_3 = double('orig3', uuid: 'o3', image?: true)
      original_docs = [original_1, original_2, original_3]

      image_result = double('img_result', metadata: { 'original_uuid' => 'o1' }, uuid: 'r1', image?: true)
      non_image_result = double('pdf_result', metadata: { 'original_uuid' => 'o2' }, uuid: 'r2', image?: false)
      orphan_image_result = double('orphan_result', metadata: {}, uuid: 'r3', image?: true)
      result_docs = [image_result, non_image_result, orphan_image_result]

      schema_relation = double('schema_relation')
      documents_relation = double('documents_relation')
      submission = double('submission', schema_documents: schema_relation)
      submitter = double('submitter', submission: submission)

      allow(submitter).to receive(:documents).and_return(documents_relation)
      allow(documents_relation).to receive(:preload).with(:blob).and_return(result_docs)
      allow(schema_relation).to receive(:preload).with(:blob).and_return(original_docs)

      selected = described_class.select_attachments(submitter)

      expect(selected).to include(orphan_image_result)
      expect(selected).not_to include(image_result)
      expect(selected).not_to include(non_image_result)
    end

    it 'keeps non-image result attachments when source has a single image' do
      original_1 = double('orig1', uuid: 'o1', image?: true)
      original_docs = [original_1]
      non_image_result = double('pdf_result', metadata: { 'original_uuid' => 'o1' }, uuid: 'r2', image?: false)
      result_docs = [non_image_result]

      schema_relation = double('schema_relation')
      documents_relation = double('documents_relation')
      submission = double('submission', schema_documents: schema_relation)
      submitter = double('submitter', submission: submission)

      allow(submitter).to receive(:documents).and_return(documents_relation)
      allow(documents_relation).to receive(:preload).with(:blob).and_return(result_docs)
      allow(schema_relation).to receive(:preload).with(:blob).and_return(original_docs)

      selected = described_class.select_attachments(submitter)

      expect(selected).to include(non_image_result)
    end
  end
end
