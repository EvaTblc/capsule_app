class ModifyColumnsInFigurineDetails < ActiveRecord::Migration[8.1]
  def change
    remove_column :figurine_details, :brand
    remove_column :figurine_details, :material
    remove_column :figurine_details, :scale

    add_column :figurine_details, :name, :string
    add_column :figurine_details, :series, :string
    add_column :figurine_details, :manufacturer, :string
    add_column :figurine_details, :line, :string
    add_column :figurine_details, :edition, :string
    add_column :figurine_details, :release_year, :integer
    add_column :figurine_details, :condition_box, :string
    add_column :figurine_details, :is_complete, :boolean
  end
end
