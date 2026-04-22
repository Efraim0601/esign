# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'securerandom'

module Templates
  module CreateAttachments
    PDF_CONTENT_TYPE = 'application/pdf'
    ZIP_CONTENT_TYPE = 'application/zip'
    X_ZIP_CONTENT_TYPE = 'application/x-zip-compressed'
    JSON_CONTENT_TYPE = 'application/json'
    DOCUMENT_EXTENSIONS = %w[.docx .doc .xlsx .xls .odt .rtf].freeze

    DOCUMENT_CONTENT_TYPES = %w[
      application/vnd.openxmlformats-officedocument.wordprocessingml.document
      application/msword
      application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
      application/vnd.ms-excel
      application/vnd.oasis.opendocument.text
      application/rtf
    ].freeze

    ANNOTATIONS_SIZE_LIMIT = 6.megabytes
    MAX_ZIP_SIZE = 100.megabytes
    InvalidFileType = Class.new(StandardError)
    PdfEncrypted = Class.new(StandardError)

    module_function

    def call(template, params, extract_fields: false, dynamic: false)
      documents = []
      dynamic_documents = []

      extract_zip_files(params[:files].presence || params[:file]).each do |file|
        docs, dynamic_docs = handle_file_types(template, file, params, extract_fields:, dynamic:)

        documents.push(*docs)
        dynamic_documents.push(*dynamic_docs)
      end

      [documents, dynamic_documents]
    end

    def handle_pdf_or_image(template, file, document_data = nil, params = {}, extract_fields: false)
      document_data ||= file.read

      if file.content_type == PDF_CONTENT_TYPE
        document_data = maybe_decrypt_pdf_or_raise(document_data, params)

        annotations =
          document_data.size < ANNOTATIONS_SIZE_LIMIT ? Templates::BuildAnnotations.call(document_data) : []
      end

      sha256 = Base64.urlsafe_encode64(Digest::SHA256.digest(document_data))

      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(document_data),
        filename: file.original_filename,
        metadata: {
          identified: file.content_type == PDF_CONTENT_TYPE,
          analyzed: file.content_type == PDF_CONTENT_TYPE,
          pdf: { annotations: }.compact_blank, sha256:
        }.compact_blank,
        content_type: file.content_type
      )

      document = template.documents.create!(blob:)

      Templates::ProcessDocument.call(document, document_data, extract_fields:)
    end

    def maybe_decrypt_pdf_or_raise(data, params)
      if data.size < ANNOTATIONS_SIZE_LIMIT && PdfUtils.encrypted?(data)
        PdfUtils.decrypt(data, params[:password])
      else
        data
      end
    rescue HexaPDF::EncryptionError
      raise PdfEncrypted
    end

    def extract_zip_files(files)
      extracted_files = []

      Array.wrap(files).each do |file|
        if file.content_type == ZIP_CONTENT_TYPE || file.content_type == X_ZIP_CONTENT_TYPE
          total_size = 0

          Zip::File.open(file.tempfile).each do |entry|
            next if entry.directory?

            total_size += entry.size

            raise InvalidFileType, 'zip_too_large' if total_size > MAX_ZIP_SIZE

            tempfile = Tempfile.new(entry.name)
            tempfile.binmode
            entry.get_input_stream { |in_stream| IO.copy_stream(in_stream, tempfile) }
            tempfile.rewind

            type = Marcel::MimeType.for(tempfile, name: entry.name)

            next if type.exclude?('image') &&
                    type != PDF_CONTENT_TYPE &&
                    type != JSON_CONTENT_TYPE &&
                    DOCUMENT_CONTENT_TYPES.exclude?(type)

            extracted_files << ActionDispatch::Http::UploadedFile.new(
              filename: File.basename(entry.name),
              type:,
              tempfile:
            )
          end
        else
          extracted_files << file
        end
      end

      extracted_files
    end

    def handle_file_types(template, file, params, extract_fields:, dynamic: false)
      if file.content_type.include?('image') || file.content_type == PDF_CONTENT_TYPE
        return [handle_pdf_or_image(template, file, file.read, params, extract_fields:), []]
      end

      if DOCUMENT_CONTENT_TYPES.include?(file.content_type) ||
         DOCUMENT_EXTENSIONS.include?(File.extname(file.original_filename.to_s).downcase)
        return [handle_office_document(template, file, params, extract_fields:), []]
      end

      raise InvalidFileType, "#{file.content_type}/#{dynamic}"
    end

    def handle_office_document(template, file, params, extract_fields:)
      pdf_data = convert_office_to_pdf(file)
      pdf_filename = "#{File.basename(file.original_filename.to_s, '.*')}.pdf"

      pdf_tempfile = Tempfile.new(['converted', '.pdf'])
      pdf_tempfile.binmode
      pdf_tempfile.write(pdf_data)
      pdf_tempfile.rewind

      pdf_uploaded = ActionDispatch::Http::UploadedFile.new(
        tempfile: pdf_tempfile,
        filename: pdf_filename,
        type: PDF_CONTENT_TYPE
      )

      handle_pdf_or_image(template, pdf_uploaded, pdf_data, params, extract_fields:)
    ensure
      pdf_tempfile&.close!
    end

    def convert_office_to_pdf(file)
      gotenberg_url = ENV.fetch('GOTENBERG_URL', 'http://gotenberg:3000')
      uri = URI.join(gotenberg_url, '/forms/libreoffice/convert')

      source = file.tempfile || file
      source.rewind if source.respond_to?(:rewind)
      filename = file.original_filename.to_s.presence || 'document.docx'

      boundary = "----esign-boundary-#{SecureRandom.hex(16)}"
      body = String.new(encoding: Encoding::ASCII_8BIT)
      body << "--#{boundary}\r\n".b
      body << %(Content-Disposition: form-data; name="files"; filename="#{filename}"\r\n).b
      body << "Content-Type: application/octet-stream\r\n\r\n".b
      body << source.read.to_s.b
      body << "\r\n--#{boundary}--\r\n".b

      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 180
      http.open_timeout = 10

      req = Net::HTTP::Post.new(uri.request_uri)
      req['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
      req.body = body

      resp = http.request(req)

      unless resp.is_a?(Net::HTTPSuccess)
        detail = resp.body.to_s[0, 500]
        raise InvalidFileType, "office_conversion_failed: HTTP #{resp.code} #{detail}"
      end

      resp.body
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Net::OpenTimeout, Net::ReadTimeout => e
      raise InvalidFileType, "office_conversion_unreachable: #{e.class} #{e.message}"
    end
  end
end
