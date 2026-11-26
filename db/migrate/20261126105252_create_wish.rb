class CreateWish < ActiveRecord::Migration[8.1]
  def change
    create_table :wishes do |t|
      t.references :collection, null: false, foreign_key: true
      t.references :author, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :product, foreign_key: { on_delete: :nullify }
      t.string :title, null: false
      t.string :platform
      t.string :edition
      t.decimal :max_price, precision: 8, scale: 2
      t.text :note
      t.timestamps
    end
    add_index :wishes, [ :collection_id, :product_id ], unique: true, where: "product_id IS NOT NULL"
  end
end
