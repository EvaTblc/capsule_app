class AddFieldsToItems < ActiveRecord::Migration[8.1]
  def change
    add_column :items, :condition, :string
    add_column :items, :barcode, :string
  end
end
