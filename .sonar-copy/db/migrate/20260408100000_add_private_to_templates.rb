class AddPrivateToTemplates < ActiveRecord::Migration[7.0]
  def change
    add_column :templates, :private, :boolean, default: false, null: false
    add_index :templates, :private
  end
end