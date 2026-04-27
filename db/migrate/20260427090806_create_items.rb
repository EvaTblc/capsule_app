class CreateItems < ActiveRecord::Migration[8.1]
  def change
    create_table :items do |t|
      t.string :title
      t.text :description
      t.date :acquired_at
      t.string :item_type
      t.references :item_detailable, polymorphic: true, null: false
      t.references :collection, null: false, foreign_key: true

      t.timestamps
    end
  end
end
