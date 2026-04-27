class CreateMusicDetails < ActiveRecord::Migration[8.1]
  def change
    create_table :music_details do |t|
      t.string :artist
      t.string :album
      t.integer :year
      t.string :label
      t.string :format

      t.timestamps
    end
  end
end
