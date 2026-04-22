# frozen_string_literal: true

require 'bcrypt'

module Docuseal
  # Creates a default admin user on self-hosted (non-multitenant) deployments when absent.
  # Credentials: ENV['DEFAULT_ADMIN_EMAIL'] (default admin@afb.com), ENV['DEFAULT_ADMIN_PASSWORD'] (default admin).
  # Passwords shorter than Devise minimum (6) are hashed with BCrypt without length validation.
  class DefaultAdminSeeder
    def self.call
      return if Docuseal.multitenant?
      return if ENV['DEFAULT_ADMIN_SEED'] == 'false'
      return unless ActiveRecord::Base.connection.data_source_exists?('users')
      return unless ActiveRecord::Base.connection.data_source_exists?('accounts')

      email = ENV.fetch('DEFAULT_ADMIN_EMAIL', 'admin@afb.com').strip.downcase
      password = ENV.fetch('DEFAULT_ADMIN_PASSWORD', 'admin')

      account =
        if email.blank? || User.exists?(email: email)
          Account.order(:id).first
        else
          existing = Account.order(:id).first
          existing || Account.create!(
            name: ENV.fetch('DEFAULT_ACCOUNT_NAME', 'AFB'),
            timezone: ENV.fetch('DEFAULT_ACCOUNT_TIMEZONE', 'UTC'),
            locale: ENV.fetch('DEFAULT_ACCOUNT_LOCALE', 'fr-FR')
          )
        end

      if account && email.present? && !User.exists?(email: email)
        user = User.new(
          account: account,
          email: email,
          role: User::ADMIN_ROLE,
          first_name: 'Admin',
          last_name: 'AFB'
        )

        if password.length >= 6
          user.password = password
          user.password_confirmation = password
          user.save!
        else
          user.encrypted_password = BCrypt::Password.create(password, cost: User.stretches).to_s
          user.save!(validate: false)
        end
      end

      ensure_default_esign_certs!(account) if account
    rescue ActiveRecord::RecordNotUnique
      # Concurrent boot: another process created the same email.
      nil
    end

    def self.ensure_default_esign_certs!(account)
      return unless ActiveRecord::Base.connection.data_source_exists?('encrypted_configs')
      return if EncryptedConfig.exists?(key: EncryptedConfig::ESIGN_CERTS_KEY)

      cert_values = GenerateCertificate.call.transform_values(&:to_pem)
      account.encrypted_configs.create!(key: EncryptedConfig::ESIGN_CERTS_KEY, value: cert_values)
      Rails.logger.info("[DefaultAdminSeeder] generated default eSign certificate for account=#{account.id}")
    rescue StandardError => e
      Rails.logger.error("[DefaultAdminSeeder] unable to seed eSign certificate: #{e.class}: #{e.message}")
    end
  end
end
