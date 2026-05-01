class RemoveCompletedFromItems < ActiveRecord::Migration[8.1]
  def change
    remove_column :items, :completed, :boolean
  end
end
