class RemoveUserIdFromCollections < ActiveRecord::Migration[8.1]
  def change
    remove_reference :collections, :user, foreign_key: true
  end
end
