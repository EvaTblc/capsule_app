class AddLatLongToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :lat, :decimal
    add_column :users, :long, :decimal
  end
end
