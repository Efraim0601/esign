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
  end
end
