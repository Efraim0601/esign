# frozen_string_literal: true

class AddDirectionToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :direction, :string
  end
end
