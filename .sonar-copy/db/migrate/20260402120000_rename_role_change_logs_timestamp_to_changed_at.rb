# frozen_string_literal: true

# `timestamp` is a reserved ActiveRecord attribute name and causes RoleChangeLog.create! to raise.
class RenameRoleChangeLogsTimestampToChangedAt < ActiveRecord::Migration[8.1]
  def up
    return unless column_exists?(:role_change_logs, :timestamp)

    rename_column :role_change_logs, :timestamp, :changed_at
  end

  def down
    return unless column_exists?(:role_change_logs, :changed_at) && !column_exists?(:role_change_logs, :timestamp)

    rename_column :role_change_logs, :changed_at, :timestamp
  end
end
