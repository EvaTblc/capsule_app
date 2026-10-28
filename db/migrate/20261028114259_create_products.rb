class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :kind, null: false
      t.string :title, null: false
      t.string :original_title
      t.integer :release_year
      t.string :creator
      t.text :description
      t.string :description_source
      t.jsonb :details, null: false, default: {}
      t.integer :igdb_id
      t.integer :tmdb_id
      t.string :wikidata_id
      t.datetime :fetched_at, null: false

      t.index :igdb_id, unique: true
      t.index :tmdb_id, unique: true
      t.index :wikidata_id, unique: true

      t.timestamps
    end
    add_check_constraint :products, "kind IN ('game', 'movie', 'book')", name: "products_kind_valid"
  end
end
