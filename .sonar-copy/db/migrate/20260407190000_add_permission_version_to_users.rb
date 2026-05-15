# frozen_string_literal: true

class AddPermissionVersionToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :permission_version, :integer, default: 0, null: false
  end
end
