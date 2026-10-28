class CreateBarcodeProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :barcode_products do |t|
      t.string :barcode, null: false
      t.string :kind, null: false
      t.string :source, null: false
      t.string :raw_title
      t.string :bnf_ark
      t.string :platform
      t.string :format
      t.string :edition
      t.string :publisher
      t.integer :release_year
      t.jsonb :details, null: false, default: {}
      t.references :product, foreign_key: { on_delete: :nullify }
      t.references :confirmed_by, foreign_key: { to_table: :users, on_delete: :nullify  }
      t.datetime :confirmed_at
      t.datetime :fetched_at, null: false
      t.index :barcode, unique: true
      t.timestamps
    end
    add_check_constraint :barcode_products, "barcode ~ '^[0-9]{13}$'", name: "barcode_products_barcode_valid"
    add_check_constraint :barcode_products, "kind IN ('game', 'movie', 'book')", name: "barcode_products_kind_valid"
    add_check_constraint :barcode_products, "source IN ('bnf', 'upcitemdb', 'ean_db')", name: "barcode_products_source_valid"
  end
end
