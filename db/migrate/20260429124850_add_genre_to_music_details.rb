class AddGenreToMusicDetails < ActiveRecord::Migration[8.1]
  def change
    add_column :music_details, :genre, :string
  end
end
