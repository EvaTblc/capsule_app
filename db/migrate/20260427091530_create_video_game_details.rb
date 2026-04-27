class CreateVideoGameDetails < ActiveRecord::Migration[8.1]
  def change
    create_table :video_game_details do |t|
      t.string :platform
      t.string :genre
      t.string :developer
      t.date :release_date

      t.timestamps
    end
  end
end
