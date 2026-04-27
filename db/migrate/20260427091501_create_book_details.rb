class CreateBookDetails < ActiveRecord::Migration[8.1]
  def change
    create_table :book_details do |t|
      t.string :author
      t.string :isbn
      t.string :publisher
      t.integer :pages
      t.string :genre

      t.timestamps
    end
  end
end
