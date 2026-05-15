# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submissions::GenerateAuditTrail do
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
