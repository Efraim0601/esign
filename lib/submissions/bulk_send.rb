# frozen_string_literal: true

require 'csv'

module Submissions
  module BulkSend
    UNMAPPABLE_FIELD_TYPES = %w[signature initials image file stamp payment verification kba].freeze
    RESERVED_HEADERS = %w[email name phone].freeze

    InvalidFile = Class.new(StandardError)

    class Result
      attr_reader :created, :skipped, :errors

      def initialize
        @created = []
        @skipped = []
        @errors = []
      end

      def total_rows
        created.size + skipped.size + errors.size
      end
    end

    module_function

    def call(file:, template:, user:)
      if template.submitters.size != 1
        raise InvalidFile,
              "L'envoi en masse ne fonctionne que pour un modèle à un seul signataire " \
              "(ce modèle en a #{template.submitters.size})."
      end

      table = parse_file(file)
      submitter_uuid = template.submitters.first['uuid']
      field_mapping = build_field_mapping(table.headers, template, submitter_uuid)

      result = Result.new
      submissions = []

      table.each_with_index do |row, idx|
        line_number = idx + 2

        next if row.to_h.values.all?(&:blank?)

        process_row(row, line_number, template, user, submitter_uuid, field_mapping, result, submissions)
      end

      if submissions.any?
        WebhookUrls.enqueue_events(submissions, 'submission.created')
        Submissions.send_signature_requests(submissions)
        SearchEntries.enqueue_reindex(submissions)
      end

      result
    end

    def process_row(row, line_number, template, user, submitter_uuid, field_mapping, result, submissions)
      email = field_value(row, 'email').to_s.strip

      if email.blank?
        result.errors << { line: line_number, email: '', reason: 'email manquant' }
        return
      end

      unless email.match?(URI::MailTo::EMAIL_REGEXP)
        result.errors << { line: line_number, email:, reason: 'email invalide' }
        return
      end

      values = field_mapping.each_with_object({}) do |(header, field), acc|
        value = row[header]
        acc[field['uuid']] = value.to_s.strip if value.present?
      end

      submission = Submissions.create_from_submitters(
        template:, user:, source: :invite,
        submissions_attrs: [{
          submitters: [{
            uuid: submitter_uuid,
            email:,
            name: field_value(row, 'name', 'nom'),
            phone: field_value(row, 'phone', 'telephone', 'téléphone'),
            values:
          }]
        }.with_indifferent_access],
        params: { 'send_completed_email' => true }
      ).first

      if submission
        submissions << submission
        result.created << { line: line_number, email: }
      else
        result.skipped << { line: line_number, email:, reason: 'ligne ignorée (données invalides)' }
      end
    rescue StandardError => e
      Rails.logger.error("[Submissions::BulkSend] line #{line_number} (#{email}): #{e.class}: #{e.message}")
      result.errors << { line: line_number, email:, reason: e.message }
    end

    def field_value(row, *candidates)
      header = row.headers.find do |h|
        h.present? && candidates.any? { |c| h.to_s.strip.casecmp?(c) }
      end

      header ? row[header].to_s.strip : nil
    end

    def build_field_mapping(headers, template, submitter_uuid)
      fields = template.fields.select do |f|
        f['submitter_uuid'] == submitter_uuid && f['name'].present? && !UNMAPPABLE_FIELD_TYPES.include?(f['type'])
      end

      Array(headers).compact.each_with_object({}) do |header, mapping|
        next if RESERVED_HEADERS.any? { |r| header.to_s.strip.casecmp?(r) }

        field = fields.find { |f| f['name'].to_s.strip.casecmp?(header.to_s.strip) }

        mapping[header] = field if field
      end
    end

    def mappable_fields(template)
      return [] if template.submitters.size != 1

      submitter_uuid = template.submitters.first['uuid']

      template.fields.select do |f|
        f['submitter_uuid'] == submitter_uuid && f['name'].present? && !UNMAPPABLE_FIELD_TYPES.include?(f['type'])
      end
    end

    def parse_file(file)
      filename = file.respond_to?(:original_filename) ? file.original_filename.to_s : ''
      ext = File.extname(filename).downcase

      case ext
      when '.csv', ''
        parse_csv(file)
      when '.xlsx'
        parse_xlsx(file)
      else
        raise InvalidFile, "Format non supporté (#{ext}). Utilisez .csv ou .xlsx"
      end
    end

    def parse_csv(file)
      content = file.read.to_s
      content = content.sub(/\A\xEF\xBB\xBF/, '')
      content.force_encoding('UTF-8') if content.respond_to?(:force_encoding)

      table = CSV.parse(content, headers: true, col_sep: detect_separator(content))

      raise InvalidFile, "Colonne manquante: 'email' est obligatoire." unless table.headers.any? do |h|
        h.to_s.strip.casecmp?('email')
      end

      table
    rescue CSV::MalformedCSVError => e
      raise InvalidFile, "CSV invalide: #{e.message}"
    end

    def parse_xlsx(file)
      require 'rubyXL'
      require 'rubyXL/convenience_methods/workbook'
      require 'rubyXL/convenience_methods/worksheet'

      workbook = RubyXL::Parser.parse_buffer(file.read)
      worksheet = workbook.worksheets.first
      raise InvalidFile, 'Fichier XLSX vide.' if worksheet.nil?

      rows = []
      headers = nil

      worksheet.each_with_index do |xrow, idx|
        next if xrow.nil?

        cells = xrow.cells.map { |c| c&.value.to_s.strip }

        if idx.zero?
          headers = cells
          next
        end

        next if cells.all?(&:blank?)

        rows << CSV::Row.new(headers, cells)
      end

      unless headers&.any? { |h| h.to_s.strip.casecmp?('email') }
        raise InvalidFile, "Colonne manquante: 'email' est obligatoire."
      end

      CSV::Table.new(rows)
    rescue InvalidFile
      raise
    rescue StandardError => e
      raise InvalidFile, "Fichier XLSX illisible: #{e.message}"
    end

    def detect_separator(content)
      first_line = content.to_s.lines.first.to_s
      return ';' if first_line.count(';') > first_line.count(',')

      ','
    end
  end
end
