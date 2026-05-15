# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Templates::CreateAttachments do
  describe '.extract_zip_files' do
    it 'returns original file when input is not a zip' do
      file = double('file', content_type: 'application/pdf')

      expect(described_class.extract_zip_files(file)).to eq([file])
    end
  end

  describe '.convert_office_to_pdf' do
    it 'returns response body on successful conversion' do
      source = StringIO.new('doc-binary')
      file = double('file', tempfile: source, original_filename: 'sample.docx')
      http = double('http')
      response = Net::HTTPSuccess.new('1.1', '200', 'OK')
      allow(response).to receive(:body).and_return('pdf-binary')

      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:request).and_return(response)

      result = described_class.convert_office_to_pdf(file)

      expect(result).to eq('pdf-binary')
    end

    it 'raises InvalidFileType when conversion endpoint returns non success' do
      source = StringIO.new('doc-binary')
      file = double('file', tempfile: source, original_filename: 'sample.docx')
      http = double('http')
      response = Net::HTTPInternalServerError.new('1.1', '500', 'Internal Server Error')
      allow(response).to receive(:body).and_return('failed')
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)

      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:request).and_return(response)

      expect do
        described_class.convert_office_to_pdf(file)
      end.to raise_error(Templates::CreateAttachments::InvalidFileType, /office_conversion_failed/)
    end
  end

  describe '.maybe_decrypt_pdf_or_raise' do
    it 'returns original data when not encrypted' do
      allow(PdfUtils).to receive(:encrypted?).and_return(false)

      data = described_class.maybe_decrypt_pdf_or_raise('pdf-bytes', {})

      expect(data).to eq('pdf-bytes')
    end

    it 'decrypts data when encrypted' do
      allow(PdfUtils).to receive(:encrypted?).and_return(true)
      allow(PdfUtils).to receive(:decrypt).with('pdf-bytes', 'pwd').and_return('decrypted')

      data = described_class.maybe_decrypt_pdf_or_raise('pdf-bytes', { password: 'pwd' })

      expect(data).to eq('decrypted')
    end

    it 'raises PdfEncrypted when decrypt fails with HexaPDF encryption error' do
      allow(PdfUtils).to receive(:encrypted?).and_return(true)
      allow(PdfUtils).to receive(:decrypt).and_raise(HexaPDF::EncryptionError.new('bad password'))

      expect do
        described_class.maybe_decrypt_pdf_or_raise('pdf-bytes', {})
      end.to raise_error(Templates::CreateAttachments::PdfEncrypted)
    end
  end

  describe '.handle_file_types' do
    it 'handles pdf/image files via handle_pdf_or_image' do
      template = double('template')
      file = double('file', content_type: 'application/pdf', original_filename: 'doc.pdf', read: 'pdf')
      attachment = double('attachment')

      allow(described_class).to receive(:handle_pdf_or_image).and_return(attachment)

      documents, dynamic = described_class.handle_file_types(template, file, {}, extract_fields: false)

      expect(documents).to eq(attachment)
      expect(dynamic).to eq([])
    end

    it 'handles office files via handle_office_document' do
      template = double('template')
      file = double('file', content_type: 'application/msword', original_filename: 'doc.doc')
      attachment = double('attachment')

      allow(described_class).to receive(:handle_office_document).and_return(attachment)

      documents, dynamic = described_class.handle_file_types(template, file, {}, extract_fields: true)

      expect(documents).to eq(attachment)
      expect(dynamic).to eq([])
    end

    it 'raises InvalidFileType for unsupported file types' do
      template = double('template')
      file = double('file', content_type: 'text/plain', original_filename: 'x.txt')

      expect do
        described_class.handle_file_types(template, file, {}, extract_fields: false)
      end.to raise_error(Templates::CreateAttachments::InvalidFileType)
    end
  end

  describe '.call' do
    it 'aggregates documents and dynamic documents from each extracted file' do
      template = double('template')
      file1 = double('file1')
      file2 = double('file2')
      allow(described_class).to receive(:extract_zip_files).and_return([file1, file2])
      allow(described_class).to receive(:handle_file_types)
        .with(template, file1, { files: ['dummy'] }, extract_fields: true, dynamic: false).and_return([[:doc1], [:dyn1]])
      allow(described_class).to receive(:handle_file_types)
        .with(template, file2, { files: ['dummy'] }, extract_fields: true, dynamic: false).and_return([[:doc2], []])

      documents, dynamic_documents = described_class.call(template, { files: ['dummy'] }, extract_fields: true)

      expect(documents).to eq([:doc1, :doc2])
      expect(dynamic_documents).to eq([:dyn1])
    end
  end
end
