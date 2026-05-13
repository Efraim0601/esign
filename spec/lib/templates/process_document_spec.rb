# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Templates::ProcessDocument do
  describe '.normalize_attachment_fields' do
    it 'assigns first template submitter uuid to extracted pdf fields' do
      attachment = double('attachment', metadata: { 'pdf' => { 'fields' => [{ 'name' => 'A' }] } })
      template = double('template', submitters: [{ 'uuid' => 'u1' }])

      fields = described_class.normalize_attachment_fields(template, [attachment])

      expect(fields).to eq([{ 'name' => 'A', 'submitter_uuid' => 'u1' }])
    end
  end

  describe '.maybe_flatten_form' do
    it 'returns original data when pdf has no acro_form' do
      pdf = double('pdf', acro_form: nil)

      expect(described_class.maybe_flatten_form('pdf-data', pdf)).to eq('pdf-data')
    end

    it 'returns original data when file is above flatten size limit' do
      data = 'x' * (Templates::ProcessDocument::MAX_FLATTEN_FILE_SIZE + 1)
      pdf = double('pdf', acro_form: double('form'))

      expect(described_class.maybe_flatten_form(data, pdf)).to eq(data)
    end
  end

  describe '.process' do
    it 'stores page count and extracted fields metadata' do
      pages = double('pages', size: 2)
      pdf = double('pdf', pages: pages)
      attachment = double('attachment', metadata: {}, content_type: 'application/pdf')
      allow(HexaPDF::Document).to receive(:new).and_return(pdf)
      allow(Templates::FindAcroFields).to receive(:call).and_return([{ 'name' => 'A' }])

      result = described_class.process(attachment, 'pdf-bytes', extract_fields: true)

      expect(result.metadata.dig('pdf', 'number_of_pages')).to eq(2)
      expect(result.metadata.dig('pdf', 'fields')).to eq([{ 'name' => 'A' }])
    end
  end

  describe '.generate_pdf_preview_images' do
    it 'saves metadata then generates images with limited range' do
      pages = double('pages', size: 3)
      pdf = double('pdf', pages: pages, acro_form: nil)
      attachment = double('attachment', metadata: {}, save!: true)
      relation = double('relation', destroy_all: true)
      allow(ActiveStorage::Attachment).to receive(:where).and_return(relation)
      allow(described_class).to receive(:maybe_flatten_form).and_return('flattened')
      allow(described_class).to receive(:generate_document_preview_images)

      described_class.generate_pdf_preview_images(attachment, 'pdf-bytes', pdf, max_pages: 2)

      expect(attachment.metadata.dig('pdf', 'number_of_pages')).to eq(3)
      expect(attachment).to have_received(:save!)
      expect(described_class).to have_received(:generate_document_preview_images).with(attachment, 'flattened', 0..2)
    end
  end

  describe '.build_and_upload_blob' do
    it 'returns nil when rendering fails with Pdfium error' do
      doc_page = double('doc_page')
      doc = double('doc', get_page: doc_page)
      allow(doc_page).to receive(:render_to_bitmap).and_raise(Pdfium::PdfiumError.new('bad render'))
      allow(doc_page).to receive(:close)

      result = described_class.build_and_upload_blob(doc, 0)

      expect(result).to be_nil
      expect(doc_page).to have_received(:close)
    end

    it 'returns nil when rendering fails with Vips error' do
      doc_page = double('doc_page')
      doc = double('doc', get_page: doc_page)
      allow(doc_page).to receive(:render_to_bitmap).and_raise(Vips::Error.new('bad render'))
      allow(doc_page).to receive(:close)

      expect(described_class.build_and_upload_blob(doc, 0)).to be_nil
      expect(doc_page).to have_received(:close)
    end

    it 'uploads jpeg blob with given format' do
      data = 'rgba-bytes'
      doc_page = double('doc_page', render_to_bitmap: [data, 100, 50])
      allow(doc_page).to receive(:close)
      doc = double('doc', get_page: doc_page)
      page = double('page', width: 100, height: 50)
      allow(page).to receive(:copy).and_return(page)
      allow(page).to receive(:write_to_buffer).with('.jpeg', interlace: true, Q: anything).and_return('jpeg-bytes')
      allow(Vips::Image).to receive(:new_from_memory).and_return(page)
      blob = double('blob')
      allow(blob).to receive(:upload)
      allow(ActiveStorage::Blob).to receive(:new).and_return(blob)

      result = described_class.build_and_upload_blob(doc, 0, '.jpeg')

      expect(result).to eq(blob)
    end
  end

  describe '.normalize_attachment_fields more cases' do
    it 'returns empty when attachments have no pdf metadata' do
      template = double('template', submitters: [{ 'uuid' => 'u1' }])
      attachment = double('attachment', metadata: {})

      expect(described_class.normalize_attachment_fields(template, [attachment])).to eq([])
    end

    it 'preserves field properties and removes from metadata' do
      attachment = double('attachment', metadata: { 'pdf' => { 'fields' => [{ 'name' => 'A' }, { 'name' => 'B' }] } })
      template = double('template', submitters: [{ 'uuid' => 'sub-1' }])

      fields = described_class.normalize_attachment_fields(template, [attachment])

      expect(fields.size).to eq(2)
      expect(fields).to all(include('submitter_uuid' => 'sub-1'))
      expect(attachment.metadata['pdf']).not_to have_key('fields')
    end
  end

  describe '.maybe_flatten_form' do
    it 'clears combo box select placeholders before flattening' do
      pdf = double('pdf', acro_form: double('form'))
      field = double('field', field_type: :Ch, concrete_field_type: :combo_box,
                              field_value: 'Select an option')
      allow(field).to receive(:[]).with(:Opt).and_return(%w[A B])
      allow(field).to receive(:[]=).with(:V, '')
      allow(pdf.acro_form).to receive(:each_field).and_yield(field)
      allow(pdf.acro_form).to receive(:[]).with(:NeedAppearances).and_return(true)
      allow(pdf.acro_form).to receive(:create_appearances)
      allow(pdf.acro_form).to receive(:flatten)
      allow(pdf).to receive(:write) { |io, **| io.write('flat') }

      result = described_class.maybe_flatten_form('orig-data', pdf)

      expect(result).to eq('flat')
      expect(field).to have_received(:[]=).with(:V, '')
    end

    it 'returns data unchanged when StandardError occurs (production)' do
      pdf = double('pdf', acro_form: double('form'))
      allow(pdf.acro_form).to receive(:each_field).and_raise(StandardError.new('boom'))
      allow(Rails.env).to receive(:development?).and_return(false)

      expect(described_class.maybe_flatten_form('orig', pdf)).to eq('orig')
    end
  end
end
