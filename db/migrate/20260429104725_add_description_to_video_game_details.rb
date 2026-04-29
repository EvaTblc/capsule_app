class AddDescriptionToVideoGameDetails < ActiveRecord::Migration[8.1]
  def change
    add_column :video_game_details, :description, :text
  end
end
