class AddWishesVisibleToFriendsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :wishes_visible_to_friends, :boolean, default: true, null: false
  end
end
