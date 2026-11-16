class CreateIgdbFrenchTitles < ActiveRecord::Migration[8.1]
  def change
    create_table :igdb_french_titles do |t|
      t.bigint :igdb_id, null: false
      t.bigint :igdb_game_id, null: false
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.index :igdb_id, unique: true
      t.timestamps
    end
  end
end
