class AddInviteTokenToCollections < ActiveRecord::Migration[8.1]
  def change
    add_column :collections, :invite_token, :string
  end
end
