class ModifyColumnsOnUsers < ActiveRecord::Migration[8.1]
  def change
    rename_column :users, :lat, :latitude
    rename_column :users, :long, :longitude
    add_column :users, :address, :string
  end
end
