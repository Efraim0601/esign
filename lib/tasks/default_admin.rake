# frozen_string_literal: true

namespace :docuseal do
  desc 'Create default admin user if missing (self-hosted, see DEFAULT_ADMIN_EMAIL / DEFAULT_ADMIN_PASSWORD)'
  task seed_default_admin: :environment do
    Docuseal::DefaultAdminSeeder.call
    puts 'Default admin check completed.'
  end
end
