class LatLongAndAdressOnEvents < ActiveRecord::Migration[8.1]
  def change
    rename_column :events, :lat, :latitude
    rename_column :events, :long, :longitude
    add_column :events, :address, :string
  end
end
