# frozen_string_literal: true

RSpec.describe Submissions::GeneratePreviewAttachments do
  describe '.call' do
    it 'generates merged preview attachment when merge is true' do
      account_configs = double('account_configs', where: [])
      account = double('account', account_configs: account_configs)
      template = double('template', name: 'Template', schema: [{ 'attachment_uuid' => 'a1', 'name' => 'Doc 1' }])
      submitter = double('submitter', id: 10)
      submitters_relation = double('submitters_relation')
      submission = double('submission',
                          account: account,
                          submitters: submitters_relation,
                          template: template,
                          template_schema: nil,
                          name: 'Submission')

      allow(described_class).to receive(:build_values_hash).with(submission).and_return('vh')
      allow(submitters_relation).to receive(:where).with(completed_at: nil).and_return(submitters_relation)
      allow(submitters_relation).to receive(:preload).with(attachments_attachments: :blob).and_return([submitter])

      page = double('page')
      source_pdf = double('source_pdf', pages: [page])
      allow(source_pdf).to receive(:dispatch_message).with(:complete_objects)
      allow(Submissions::GenerateResultAttachments).to receive(:build_pdfs_index).and_return({ 'a1' => source_pdf })
      allow(Submissions::GenerateResultAttachments).to receive(:fill_submitter_fields)

      result_pages = []
      result_pdf = double('result_pdf', pages: result_pages)
      allow(result_pdf).to receive(:import).with(page).and_return(:imported_page)
      allow(HexaPDF::Document).to receive(:new).and_return(result_pdf)

      attachment = double('attachment')
      allow(attachment).to receive(:save!)
      allow(described_class).to receive(:build_pdf_attachment).and_return(attachment)
      allow(ApplicationRecord).to receive(:no_touching).and_yield

      result = described_class.call(submission, merge: true)

      expect(result).to eq([attachment])
      expect(Submissions::GenerateResultAttachments).to have_received(:fill_submitter_fields).with(
        submitter, account, kind_of(Hash), hash_including(with_headings: true)
      )
      expect(described_class).to have_received(:build_pdf_attachment).with(hash_including(name: 'preview_merged_document'))
      expect(attachment).to have_received(:save!)
    end

    it 'builds per-document and merged image attachments when there are multiple image pdfs' do
      account_configs = double('account_configs', where: [])
      account = double('account', account_configs: account_configs)
      template = double('template', name: 'Template',
                                    schema: [{ 'attachment_uuid' => 'a1', 'name' => 'IMG-1' },
                                             { 'attachment_uuid' => 'a2', 'name' => 'IMG-2' }])
      submitters_relation = double('submitters_relation')
      schema_documents_relation = double('schema_documents_relation')
      submission = double('submission',
                          account: account,
                          submitters: submitters_relation,
                          schema_documents: schema_documents_relation,
                          template: template,
                          template_schema: nil,
                          name: 'Submission')

      allow(described_class).to receive(:build_values_hash).with(submission).and_return('vh')
      allow(submitters_relation).to receive(:where).with(completed_at: nil).and_return(submitters_relation)
      allow(submitters_relation).to receive(:preload).with(attachments_attachments: :blob).and_return([])

      original_1 = double('original_1', uuid: 'a1', image?: true)
      original_2 = double('original_2', uuid: 'a2', image?: true)
      allow(schema_documents_relation).to receive(:preload).with(:blob).and_return([original_1, original_2])

      page1 = double('page1')
      page2 = double('page2')
      pdf1 = double('pdf1', pages: [page1])
      pdf2 = double('pdf2', pages: [page2])
      allow(Submissions::GenerateResultAttachments).to receive(:build_pdfs_index).and_return({ 'a1' => pdf1, 'a2' => pdf2 })
      allow(Submissions::GenerateResultAttachments).to receive(:fill_submitter_fields)
      allow(Submissions::GenerateResultAttachments).to receive(:normalize_image_pdf).and_return(pdf1, pdf2, :normalized_merged)
      allow(Submissions::GenerateResultAttachments).to receive(:images_pdf_uuid).and_return('images-uuid')

      merged_pages = []
      merged_images_pdf = double('merged_images_pdf', pages: merged_pages)
      allow(merged_images_pdf).to receive(:import).and_return(:imported_page)
      allow(HexaPDF::Document).to receive(:new).and_return(merged_images_pdf)

      attachment_1 = double('attachment_1')
      attachment_2 = double('attachment_2')
      images_attachment = double('images_attachment')
      [attachment_1, attachment_2, images_attachment].each { |att| allow(att).to receive(:save!) }
      allow(described_class).to receive(:build_pdf_attachment).and_return(attachment_1, attachment_2, images_attachment)
      allow(ApplicationRecord).to receive(:no_touching).and_yield

      result = described_class.call(submission)

      expect(result).to eq([attachment_1, attachment_2, images_attachment])
      expect(Submissions::GenerateResultAttachments).to have_received(:normalize_image_pdf).at_least(:twice)
      expect(Submissions::GenerateResultAttachments).to have_received(:images_pdf_uuid).with([original_1, original_2])
      expect(images_attachment).to have_received(:save!)
    end
  end

  describe '.build_values_hash' do
    it 'builds a digest from merged submitter values' do
      s1 = double('submitter1', values: { 'a' => 1 })
      s2 = double('submitter2', values: { 'b' => 2 })
      submission = double('submission', submitters: [s1, s2])

      digest = described_class.build_values_hash(submission)

      expect(digest).to eq(Digest::MD5.hexdigest({ 'a' => 1, 'b' => 2 }.to_json))
    end
  end

  describe '.build_pdf_attachment' do
    it 'falls back to non-incremental write on malformed pdf' do
      submission = double('submission')
      pdf = double('pdf')
      io_string = '%PDF-content'
      allow(pdf).to receive(:write).with(anything, incremental: true, validate: false)
                                  .and_raise(HexaPDF::MalformedPDFError.new('malformed'))
      allow(pdf).to receive(:write).with(anything, incremental: false, validate: false) do |io, **|
        io.write(io_string)
      end

      blob = double('blob')
      allow(ActiveStorage::Blob).to receive(:create_and_upload!).and_return(blob)
      attachment = double('attachment')
      allow(ActiveStorage::Attachment).to receive(:new).and_return(attachment)

      result = described_class.build_pdf_attachment(
        pdf: pdf,
        submission: submission,
        filename: 'preview.pdf',
        values_hash: 'abc'
      )

      expect(result).to eq(attachment)
      expect(ActiveStorage::Blob).to have_received(:create_and_upload!)
      expect(ActiveStorage::Attachment).to have_received(:new).with(hash_including(
                                                                   blob: blob,
                                                                   metadata: hash_including('values_hash': 'abc')
                                                                 ))
    end
  end

  describe '.build_submitter_values_hash' do
    let(:relation_class) do
      Class.new do
        def initialize(items)
          @items = items
        end

        def where(**kwargs)
          filtered = @items
          filtered = filtered.select { |s| s.id == kwargs[:id] } if kwargs.key?(:id)
          if kwargs.key?(:completed_at) && kwargs[:completed_at].nil?
            filtered = filtered.select { |s| s.completed_at.nil? }
          end
          self.class.new(filtered)
        end

        def not(completed_at: nil)
          self.class.new(@items.reject { |s| s.completed_at == completed_at })
        end

        def or(other)
          self.class.new((@items + other.to_a).uniq)
        end

        def reduce(seed, &block)
          @items.reduce(seed, &block)
        end

        def to_a
          @items
        end
      end
    end

    it 'builds digest from completed submitters plus current submitter' do
      s1 = Struct.new(:id, :completed_at, :values).new(1, Time.now, { 'a' => 1 }) # rubocop:disable Rails/TimeZone
      s2 = Struct.new(:id, :completed_at, :values).new(2, nil, { 'b' => 2 })
      relation = relation_class.new([s1, s2])
      submitter = double('submitter', id: 2, submission: double('submission', submitters: relation))

      digest = described_class.build_submitter_values_hash(submitter)

      expect(digest).to eq(Digest::MD5.hexdigest({ 'a' => 1, 'b' => 2 }.to_json))
    end
  end
end
