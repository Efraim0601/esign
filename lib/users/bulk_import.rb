# frozen_string_literal: true

require 'csv'

module Users
  module BulkImport
    REQUIRED_HEADERS = %w[email first_name last_name role].freeze

    ROLE_ALIASES = {
      'admin' => 'admin',
      'administrateur' => 'admin',
      'administrator' => 'admin',
      'editor' => 'editor',
      'editeur' => 'editor',
      'éditeur' => 'editor',
      'member' => 'member',
      'membre' => 'member',
      'agent' => 'agent',
      'viewer' => 'viewer',
      'observateur' => 'viewer',
      'observer' => 'viewer'
    }.freeze

    Row = Struct.new(:email, :first_name, :last_name, :role, keyword_init: true)

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

    InvalidFile = Class.new(StandardError)

    module_function

    def call(file:, account:)
      rows = parse_rows(file)
      result = Result.new

      rows.each_with_index do |row, idx|
        line_number = idx + 2 # header is line 1; data rows start at 2

        process_row(row, line_number, account, result)
      end

      result
    end

    def process_row(row, line_number, account, result)
      email = row.email.to_s.strip.downcase

      if email.blank?
        result.errors << { line: line_number, email: '', reason: 'email manquant' }
        return
      end

      unless email.match?(URI::MailTo::EMAIL_REGEXP)
        result.errors << { line: line_number, email: email, reason: 'email invalide' }
        return
      end

      role = normalize_role(row.role)

      if User.exists?(email: email)
        result.skipped << { line: line_number, email: email, reason: 'utilisateur existe déjà' }
        return
      end

      user = User.new(
        account: account,
        email: email,
        first_name: row.first_name.to_s.strip,
        last_name: row.last_name.to_s.strip,
        role: role,
        password: SecureRandom.hex(16)
      )

      if user.save
        begin
          UserMailer.invitation_email(user).deliver_later!
        rescue StandardError => e
          Rails.logger.warn("[BulkImport] invitation email queue failed for #{email}: #{e.message}")
        end
        result.created << { line: line_number, email: email, role: role }
      else
        result.errors << { line: line_number, email: email, reason: user.errors.full_messages.join(', ') }
      end
    rescue StandardError => e
      Rails.logger.error("[BulkImport] line #{line_number} (#{email}) failed: #{e.class}: #{e.message}")
      result.errors << { line: line_number, email: email, reason: "#{e.class}: #{e.message}" }
    end

    def normalize_role(value)
      key = value.to_s.strip.downcase
      ROLE_ALIASES[key] || (User::ROLES.include?(key) ? key : 'member')
    end

    def parse_rows(file)
      filename = file.respond_to?(:original_filename) ? file.original_filename.to_s : ''
      ext = File.extname(filename).downcase

      case ext
      when '.csv', ''
        parse_csv(file)
      when '.xlsx'
        parse_xlsx(file)
      else
        raise InvalidFile, "Format non supporté (#{ext}). Utilisez .xlsx ou .csv"
      end
    end

    def parse_csv(file)
      content = file.read.to_s
      content = content.sub(/\A\xEF\xBB\xBF/, '') # strip UTF-8 BOM
      content.force_encoding('UTF-8') if content.respond_to?(:force_encoding)

      table = CSV.parse(content, headers: true, col_sep: detect_separator(content))
      validate_headers!(table.headers)

      table.filter_map do |r|
        next if r.to_h.values.all?(&:blank?)

        Row.new(
          email: r['email'] || r['Email'] || r['EMAIL'],
          first_name: r['first_name'] || r['prenom'] || r['prénom'],
          last_name: r['last_name'] || r['nom'],
          role: r['role'] || r['rôle']
        )
      end
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
          headers = cells.map(&:downcase)
          validate_headers!(headers)
          next
        end

        next if cells.all?(&:blank?)

        data = headers.zip(cells).to_h
        rows << Row.new(
          email: data['email'],
          first_name: data['first_name'] || data['prenom'] || data['prénom'],
          last_name: data['last_name'] || data['nom'],
          role: data['role'] || data['rôle']
        )
      end

      rows
    rescue StandardError => e
      raise InvalidFile, "Fichier XLSX illisible: #{e.message}"
    end

    def validate_headers!(headers)
      normalized = Array(headers).compact.map { |h| h.to_s.downcase.strip }
      return if REQUIRED_HEADERS.all? { |h| normalized.include?(h) }

      missing = REQUIRED_HEADERS - normalized
      raise InvalidFile, "Colonnes manquantes: #{missing.join(', ')}. Colonnes attendues: #{REQUIRED_HEADERS.join(', ')}."
    end

    def detect_separator(content)
      first_line = content.to_s.lines.first.to_s
      return ';' if first_line.count(';') > first_line.count(',')

      ','
    end
  end
end
