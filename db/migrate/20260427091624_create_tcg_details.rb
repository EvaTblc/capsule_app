class CreateTcgDetails < ActiveRecord::Migration[8.1]
  def change
    create_table :tcg_details do |t|
      t.string :card_set
      t.string :rarity
      t.string :condition
      t.string :card_number
      t.string :game

      t.timestamps
    end
  end
end
