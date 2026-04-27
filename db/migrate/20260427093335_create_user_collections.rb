class CreateUserCollections < ActiveRecord::Migration[8.1]
  def change
    create_table :user_collections do |t|
      t.references :user, null: false, foreign_key: true
      t.references :collection, null: false, foreign_key: true
      t.string :role

      t.timestamps
    end
  end
end
