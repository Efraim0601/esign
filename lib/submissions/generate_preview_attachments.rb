# frozen_string_literal: true

module Submissions
  module GeneratePreviewAttachments
    module_function

    def call(submission, values_hash: nil, submitter: nil, merge: false)
      values_hash ||= submitter ? build_submitter_values_hash(submitter) : build_values_hash(submission)

      opts = load_preview_options(submission)
      pdfs_index = GenerateResultAttachments.build_pdfs_index(submission, flatten: opts[:is_flatten])

      fill_preview_submitters(submission, submitter, pdfs_index, opts)

      if merge
        build_merged_preview(submission, pdfs_index, values_hash)
      else
        build_split_preview(submission, submitter, pdfs_index, values_hash)
      end
    end

    def load_preview_options(submission)
      configs = submission.account.account_configs.where(key: [AccountConfig::FLATTEN_RESULT_PDF_KEY,
                                                               AccountConfig::WITH_SIGNATURE_ID,
                                                               AccountConfig::WITH_SUBMITTER_TIMEZONE_KEY,
                                                               AccountConfig::WITH_TIMESTAMP_SECONDS_KEY,
                                                               AccountConfig::WITH_FILE_LINKS_KEY,
                                                               AccountConfig::WITH_SIGNATURE_ID_REASON_KEY])

      {
        with_signature_id: configs.find { |c| c.key == AccountConfig::WITH_SIGNATURE_ID }&.value != false,
        with_file_links: configs.find { |c| c.key == AccountConfig::WITH_FILE_LINKS_KEY }&.value == true,
        is_flatten: configs.find { |c| c.key == AccountConfig::FLATTEN_RESULT_PDF_KEY }&.value != false,
        with_submitter_timezone:
          configs.find { |c| c.key == AccountConfig::WITH_SUBMITTER_TIMEZONE_KEY }&.value == true,
        with_timestamp_seconds:
          configs.find { |c| c.key == AccountConfig::WITH_TIMESTAMP_SECONDS_KEY }&.value == true,
        with_signature_id_reason:
          configs.find { |c| c.key == AccountConfig::WITH_SIGNATURE_ID_REASON_KEY }&.value != false
      }
    end

    def fill_preview_submitters(submission, submitter, pdfs_index, opts)
      submitters = submitter ? submission.submitters.where(id: submitter.id)
                             : submission.submitters.where(completed_at: nil)

      submitters.preload(attachments_attachments: :blob).each_with_index do |s, index|
        GenerateResultAttachments.fill_submitter_fields(s, submission.account, pdfs_index,
                                                        with_headings: index.zero?,
                                                        **opts)
      end
    end

    def build_merged_preview(submission, pdfs_index, values_hash)
      template = submission.template
      result = HexaPDF::Document.new

      (submission.template_schema || template.schema).each do |item|
        pdf = pdfs_index[item['attachment_uuid']]
        next unless pdf

        pdf.dispatch_message(:complete_objects)
        pdf.pages.each { |page| result.pages << result.import(page) }
      end

      attachment = build_pdf_attachment(
        pdf: result, submission:, values_hash:,
        name: 'preview_merged_document',
        filename: "#{submission.name || template.name}.pdf"
      )

      ApplicationRecord.no_touching { attachment.save! }
      [attachment]
    end

    def build_split_preview(submission, submitter, pdfs_index, values_hash)
      template = submission.template
      image_pdfs = []
      original_documents = submission.schema_documents.preload(:blob)

      result_attachments =
        (submission.template_schema || template.schema).filter_map do |item|
          build_split_attachment(item, submission, submitter, pdfs_index,
                                 original_documents, image_pdfs, values_hash)
        end

      return ApplicationRecord.no_touching { result_attachments.map { |e| e.tap(&:save!) } } if image_pdfs.size < 2

      result_attachments << build_combined_images_attachment(image_pdfs, submission, submitter, template,
                                                             original_documents, values_hash)

      ApplicationRecord.no_touching { result_attachments.map { |e| e.tap(&:save!) } }
    end

    def build_split_attachment(item, submission, submitter, pdfs_index, original_documents, image_pdfs, values_hash)
      pdf = pdfs_index[item['attachment_uuid']]
      return if pdf.nil?

      if original_documents.find { |a| a.uuid == item['attachment_uuid'] }.image?
        pdf = GenerateResultAttachments.normalize_image_pdf(pdf)
        image_pdfs << pdf
      end

      build_pdf_attachment(pdf:, submission:, submitter:,
                           uuid: item['attachment_uuid'],
                           values_hash:,
                           filename: "#{item['name']}.pdf")
    end

    def build_combined_images_attachment(image_pdfs, submission, submitter, template, original_documents, values_hash)
      images_pdf = image_pdfs.each_with_object(HexaPDF::Document.new) do |pdf, doc|
        pdf.pages.each { |page| doc.pages << doc.import(page) }
      end

      images_pdf = GenerateResultAttachments.normalize_image_pdf(images_pdf)

      build_pdf_attachment(
        pdf: images_pdf, submission:, submitter:,
        uuid: GenerateResultAttachments.images_pdf_uuid(original_documents.select(&:image?)),
        values_hash:,
        filename: "#{submission.name || template.name}.pdf"
      )
    end

    def build_values_hash(submission)
      Digest::MD5.hexdigest(
        submission.submitters.reduce({}) { |acc, s| acc.merge(s.values) }.to_json
      )
    end

    def build_submitter_values_hash(submitter)
      submission = submitter.submission

      Digest::MD5.hexdigest(
        submission.submitters.where.not(completed_at: nil).or(submission.submitters.where(id: submitter.id))
                  .reduce({}) { |acc, s| acc.merge(s.values) }.to_json
      )
    end

    def build_pdf_attachment(pdf:, submission:, filename:, values_hash:, submitter: nil, uuid: nil,
                             name: 'preview_documents')
      io = StringIO.new

      begin
        pdf.write(io, incremental: true, validate: false)
      rescue HexaPDF::MalformedPDFError => e
        Rollbar.error(e) if defined?(Rollbar)

        pdf.write(io, incremental: false, validate: false)
      end

      ActiveStorage::Attachment.new(
        blob: ActiveStorage::Blob.create_and_upload!(io: io.tap(&:rewind), filename:),
        io_data: io.string,
        metadata: { original_uuid: uuid,
                    values_hash:,
                    analyzed: true,
                    sha256: Base64.urlsafe_encode64(Digest::SHA256.digest(io.string)) }.compact,
        name: name,
        record: submitter || submission
      )
    end
    # rubocop:enable Metrics
  end
end
