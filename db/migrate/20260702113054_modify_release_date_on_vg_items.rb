class ModifyReleaseDateOnVgItems < ActiveRecord::Migration[8.1]
  def change
    change_column :video_game_details, :release_date, :integer, using: 'EXTRACT(YEAR FROM release_date)::integer'
  end
end
