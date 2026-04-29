class AddDescriptionToBookDetails < ActiveRecord::Migration[8.1]
  def change
    add_column :book_details, :description, :text
  end
end
