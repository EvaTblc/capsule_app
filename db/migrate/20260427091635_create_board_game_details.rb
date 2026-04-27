class CreateBoardGameDetails < ActiveRecord::Migration[8.1]
  def change
    create_table :board_game_details do |t|
      t.integer :min_players
      t.integer :max_players
      t.integer :duration
      t.string :publisher

      t.timestamps
    end
  end
end
