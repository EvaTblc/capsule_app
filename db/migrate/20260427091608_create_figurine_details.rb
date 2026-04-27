class CreateFigurineDetails < ActiveRecord::Migration[8.1]
  def change
    create_table :figurine_details do |t|
      t.string :brand
      t.string :scale
      t.string :material
      t.boolean :limited_edition

      t.timestamps
    end
  end
end
