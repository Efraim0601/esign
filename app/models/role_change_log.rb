# frozen_string_literal: true

# == Schema Information
#
# Table name: role_change_logs
#
class RoleChangeLog < ApplicationRecord
  belongs_to :user
  belongs_to :changed_by, class_name: 'User', foreign_key: :changed_by
  belongs_to :changed_by_user, class_name: 'User', foreign_key: :changed_by

  validates :changed_by, :user_id, :old_role, :new_role, :timestamp, presence: true
end

