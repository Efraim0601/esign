# frozen_string_literal: true

module Templates
  module ReplaceAttachments
    module_function

    def call(template, params = {}, extract_fields: false)
      documents, = Templates::CreateAttachments.call(template, params, extract_fields:)
      submitter = template.submitters.first

      documents.each_with_index do |document, index|
        replace_document_in_schema(template, document, index)
        next if template.fields.any? { |f| f['areas']&.any? { |a| a['attachment_uuid'] == document.uuid } }
        next if submitter.blank? || document.metadata.dig('pdf', 'fields').blank?

        merge_pdf_fields(template, document, submitter, index)
      end

      documents
    end

    def replace_document_in_schema(template, document, index)
      replaced_document_schema = template.schema[index]
      template.schema[index] = { attachment_uuid: document.uuid, name: document.filename.base }
      return unless replaced_document_schema

      template.fields.each do |field|
        next if field['areas'].blank?

        field['areas'].each do |area|
          area['attachment_uuid'] = document.uuid if area['attachment_uuid'] == replaced_document_schema['attachment_uuid']
        end
      end
    end

    def merge_pdf_fields(template, document, submitter, index)
      pdf_fields = document.metadata['pdf'].delete('fields').to_a
      pdf_fields.each { |f| f['submitter_uuid'] = submitter['uuid'] }
      return if pdf_fields.blank?

      if index.positive? && previous_document_has_anchored_field?(template, index)
        template.fields.insert(index, *pdf_fields)
      else
        template.fields += pdf_fields
        template.schema[index]['pending_fields'] = true unless index.positive?
      end
    end

    def previous_document_has_anchored_field?(template, index)
      preview_document = template.schema[index - 1]
      preview_document_last_field = template.fields.reverse.find do |f|
        f['areas']&.any? { |a| a['attachment_uuid'] == preview_document[:attachment_uuid] }
      end
      return false unless preview_document_last_field

      template.fields.find_index { |f| f['uuid'] == preview_document_last_field['uuid'] }
    end
  end
end
