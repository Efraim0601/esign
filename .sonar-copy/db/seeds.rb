# frozen_string_literal: true

# Optional: run `bin/rails db:seed` in production to ensure the default admin exists
# (same logic as boot-time seeding in config/initializers/migrate.rb).
Docuseal::DefaultAdminSeeder.call if Rails.env.production? && ENV['DEFAULT_ADMIN_SEED'] != 'false'
