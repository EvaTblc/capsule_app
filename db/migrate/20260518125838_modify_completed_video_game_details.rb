class ModifyCompletedVideoGameDetails < ActiveRecord::Migration[8.1]
  def change
    remove_column :video_game_details, :completed
    add_column :video_game_details, :completed, :boolean, default: false
  end
end
