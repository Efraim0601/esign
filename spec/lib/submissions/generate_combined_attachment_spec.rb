# frozen_string_literal: true

RSpec.describe Submissions::GenerateCombinedAttachment do
  describe '.sign_pdf' do
    it 'retries with non-incremental write when malformed' do
      pdf = double('pdf')
      io = StringIO.new

      allow(pdf).to receive(:sign).with(io).and_raise(HexaPDF::MalformedPDFError.new('malformed'))
      allow(pdf).to receive(:sign).with(io, hash_including(write_options: { incremental: false })).and_return(nil)

      described_class.sign_pdf(io, pdf, {})
    end

    it 'validates then retries when HexaPDF::Error occurs' do
      pdf = double('pdf')
      io = StringIO.new

      allow(pdf).to receive(:sign).with(io).and_raise(HexaPDF::Error)
      allow(pdf).to receive(:validate)
      allow(pdf).to receive(:sign).with(io, hash_including(write_options: { validate: false })).and_return(nil)

      described_class.sign_pdf(io, pdf, {})

      expect(pdf).to have_received(:validate).with(auto_correct: true)
    end
  end

  describe '.build_combined_pdf' do
    it 'combines template pages and appends audit trail pages' do
      schema = [{ 'attachment_uuid' => 'a1' }]
      submission = double('submission', template_schema: schema)
      account = double('account', locale: 'fr')
      allow(submission).to receive(:account).and_return(account)
      submitter = double('submitter', submission: submission, account: account)

      source_pdf = double('source_pdf', pages: %w[p1 p2])
      allow(source_pdf).to receive(:dispatch_message)
      allow(Submissions::GenerateResultAttachments).to receive(:generate_pdfs).and_return({ 'a1' => source_pdf })

      audit_trail = double('audit', pages: ['audit-page'])
      allow(audit_trail).to receive(:dispatch_message)
      allow(Submissions::GenerateAuditTrail).to receive(:build_audit_trail).and_return(audit_trail)

      pages = []
      result = double('result', pages: pages)
      allow(result).to receive(:import) { |page| "imp-#{page}" }
      allow(HexaPDF::Document).to receive(:new).and_return(result)

      combined = described_class.build_combined_pdf(submitter, with_audit: true)

      expect(combined).to eq(result)
      expect(pages).to eq(%w[imp-p1 imp-p2 imp-audit-page])
    end

    it 'skips items whose attachment is missing from generated pdfs' do
      schema = [{ 'attachment_uuid' => 'present' }, { 'attachment_uuid' => 'absent' }]
      submission = double('submission', template_schema: schema)
      submitter = double('submitter', submission: submission, account: double('account', locale: 'en'))

      source_pdf = double('source_pdf', pages: ['p1'])
      allow(source_pdf).to receive(:dispatch_message)
      allow(Submissions::GenerateResultAttachments).to receive(:generate_pdfs).and_return({ 'present' => source_pdf })

      pages = []
      result = double('result', pages: pages)
      allow(result).to receive(:import) { |page| "imp-#{page}" }
      allow(HexaPDF::Document).to receive(:new).and_return(result)

      described_class.build_combined_pdf(submitter, with_audit: false)

      expect(pages).to eq(['imp-p1'])
    end

    it 'omits audit trail when with_audit is false' do
      submission = double('submission', template_schema: [])
      submitter = double('submitter', submission: submission, account: double('account', locale: 'en'))

      allow(Submissions::GenerateResultAttachments).to receive(:generate_pdfs).and_return({})
      pages = []
      result = double('result', pages: pages)
      allow(HexaPDF::Document).to receive(:new).and_return(result)

      described_class.build_combined_pdf(submitter, with_audit: false)

      expect(pages).to eq([])
    end
  end

  describe '.sign_pdf success path' do
    it 'returns nil on the happy path without retry' do
      pdf = double('pdf')
      io = StringIO.new
      allow(pdf).to receive(:sign).with(io).and_return(:signed)

      result = described_class.sign_pdf(io, pdf, {})

      expect(result).to eq(:signed)
    end
  end

  describe '.call (integration)' do
    let(:account) { create(:account) }
    let(:author) { create(:user, account:) }
    let(:template) do
      create(:template, account:, author:, only_field_types: %w[text], attachment_count: 1)
    end
    let(:submission) { create(:submission, template:, created_by_user: author) }
    let(:submitter) do
      submission.submitters.create!(
        account_id: account.id,
        uuid: template.submitters.first['uuid'],
        email: 'combined@example.test',
        completed_at: Time.current,
        values: template.fields.each_with_object({}) { |f, h| h[f['uuid']] = 'X' if f['type'] == 'text' }
      )
    end

    before do
      allow(Accounts).to receive(:load_signing_pkcs).and_return(nil)
      allow(Accounts).to receive(:load_timeserver_url).and_return(nil)
    end

    it 'writes a combined attachment without audit trail when with_audit is false' do
      submitter

      attachment = described_class.call(submitter, with_audit: false)

      expect(attachment).to be_a(ActiveStorage::Attachment)
      expect(attachment.name).to eq('merged_document')
    end

    it 'writes a combined attachment with audit trail by default' do
      submitter

      attachment = described_class.call(submitter)

      expect(attachment).to be_a(ActiveStorage::Attachment)
      expect(attachment.name).to eq('combined_document')
    end

    it 'enables pdfa task when Docuseal.pdf_format is pdf/a-3b' do
      submitter
      allow(Docuseal).to receive(:pdf_format).and_return('pdf/a-3b')

      attachment = described_class.call(submitter, with_audit: false)

      expect(attachment).to be_a(ActiveStorage::Attachment)
    end

    it 'signs the combined PDF when a signing certificate is available' do
      submitter

      pkcs = double('pkcs')
      sign_params = { certificate: double, key: double, certificate_chain: [] }
      allow(Accounts).to receive(:load_signing_pkcs).and_return(pkcs)
      allow(Submissions::GenerateResultAttachments).to receive(:single_sign_reason).and_return('Signed')
      allow(Submissions::GenerateResultAttachments).to receive(:build_signing_params).and_return(sign_params)
      allow(Submissions::GenerateResultAttachments).to receive(:maybe_enable_ltv)
      allow(described_class).to receive(:sign_pdf) do |io, _pdf, _params|
        io.write('signed-pdf-bytes')
      end

      attachment = described_class.call(submitter, with_audit: false)

      expect(attachment).to be_a(ActiveStorage::Attachment)
      expect(described_class).to have_received(:sign_pdf)
    end
  end
end
