class CreateNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :notes do |t|
      t.string :title
      t.text :comment
      t.references :user, null: false, foreign_key: true
      t.boolean :reminder

      t.timestamps
    end
  end
end
