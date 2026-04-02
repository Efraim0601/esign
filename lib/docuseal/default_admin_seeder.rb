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

      return if email.blank?
      return if User.exists?(email: email)

      account = Account.order(:id).first
      account ||= Account.create!(
        name: ENV.fetch('DEFAULT_ACCOUNT_NAME', 'AFB'),
        timezone: ENV.fetch('DEFAULT_ACCOUNT_TIMEZONE', 'UTC'),
        locale: ENV.fetch('DEFAULT_ACCOUNT_LOCALE', 'fr-FR')
      )

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
    rescue ActiveRecord::RecordNotUnique
      # Concurrent boot: another process created the same email.
      nil
    end
  end
end
