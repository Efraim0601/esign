# frozen_string_literal: true

Rails.application.config.after_initialize do
  next unless ENV['RAILS_ENV'] == 'production'
  next if ENV['RUN_MIGRATIONS'] == 'false'

  attempts = ENV.fetch('DB_BOOTSTRAP_MAX_ATTEMPTS', '40').to_i
  sleep_s = ENV.fetch('DB_BOOTSTRAP_SLEEP_SECONDS', '1.5').to_f
  rescuable = [ActiveRecord::ConnectionNotEstablished, ActiveRecord::NoDatabaseError]
  rescuable << ActiveRecord::DatabaseConnectionError if defined?(ActiveRecord::DatabaseConnectionError)
  rescuable << PG::ConnectionBad if defined?(PG::ConnectionBad)

  (1..attempts).each do |n|
    ActiveRecord::Tasks::DatabaseTasks.migrate
    Rails.logger.info('[migrate.rb] Database migrations applied successfully.')
    break
  rescue *rescuable => e
    if n >= attempts
      hint = <<~MSG.squish
        Cannot reach the database after #{attempts} attempts (#{e.class}: #{e.message}).
        Start the full stack so hostnames resolve, e.g. `docker compose up -d` (not `docker compose up --no-deps app`).
        For an external database, set DATABASE_URL to a reachable host.
      MSG
      Rails.logger.error("[migrate.rb] #{hint}")
      warn("[migrate.rb] #{hint}")
      raise
    end

    Rails.logger.warn("[migrate.rb] Database not ready (#{n}/#{attempts}): #{e.message}")
    sleep(sleep_s)
    ActiveRecord::Base.connection_handler.clear_active_connections!(:all)
  end

  next if ENV['DEFAULT_ADMIN_SEED'] == 'false'

  begin
    Docuseal::DefaultAdminSeeder.call
  rescue StandardError => e
    Rails.logger.error("[DefaultAdminSeeder] #{e.class}: #{e.message}")
    Rails.logger.error(e.backtrace&.first(8)&.join("\n"))
  end
end
