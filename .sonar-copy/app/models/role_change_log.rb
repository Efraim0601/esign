# frozen_string_literal: true

# == Schema Information
#
# Table name: role_change_logs
#
class RoleChangeLog < ApplicationRecord
  belongs_to :user
  belongs_to :changed_by_user, class_name: 'User', foreign_key: :changed_by, inverse_of: false

  validates :changed_by, :user_id, :old_role, :new_role, :changed_at, presence: true
end
