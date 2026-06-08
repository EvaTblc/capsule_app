class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.string :title
      t.text :comment
      t.boolean :reminder
      t.date :date
      t.decimal :lat
      t.decimal :long
      t.string :url
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
