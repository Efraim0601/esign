# frozen_string_literal: true

class AddTimestampsToRoleChangeLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :role_change_logs, :created_at, :datetime, null: false, default: -> { 'CURRENT_TIMESTAMP' }
    add_column :role_change_logs, :updated_at, :datetime, null: false, default: -> { 'CURRENT_TIMESTAMP' }
  end
end

