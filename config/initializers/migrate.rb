# frozen_string_literal: true

Rails.configuration.to_prepare do
  next unless ENV['RAILS_ENV'] == 'production'

  ActiveRecord::Tasks::DatabaseTasks.migrate if ENV['RUN_MIGRATIONS'] != 'false'

  if ENV['DEFAULT_ADMIN_SEED'] != 'false'
    begin
      Docuseal::DefaultAdminSeeder.call
    rescue StandardError => e
      Rails.logger.error("[DefaultAdminSeeder] #{e.class}: #{e.message}")
      Rails.logger.error(e.backtrace&.first(8)&.join("\n"))
    end
  end
end
