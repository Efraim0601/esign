# frozen_string_literal: true

class CreateRoleChangeLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :role_change_logs, id: :bigint do |t|
      t.bigint :changed_by, null: false
      t.bigint :user_id, null: false
      t.string :old_role, null: false
      t.string :new_role, null: false
      t.datetime :timestamp, null: false
    end

    add_index :role_change_logs, :changed_by
    add_index :role_change_logs, :user_id
    add_index :role_change_logs, :timestamp

    add_foreign_key :role_change_logs, :users, column: :changed_by
    add_foreign_key :role_change_logs, :users, column: :user_id
  end
end

