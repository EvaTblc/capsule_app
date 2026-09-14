class AddSummaryEnToVideoGameDetails < ActiveRecord::Migration[8.1]
  def change
    add_column :video_game_details, :summary_en, :text
  end
end
