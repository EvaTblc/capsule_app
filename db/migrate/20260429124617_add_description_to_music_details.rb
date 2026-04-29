class AddDescriptionToMusicDetails < ActiveRecord::Migration[8.1]
  def change
    add_column :music_details, :description, :text
  end
end
