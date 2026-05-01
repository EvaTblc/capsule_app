class AddCompletedStatusAndCommentsOnItems < ActiveRecord::Migration[8.1]
  def change
    add_column :items, :completed, :boolean
    add_column :items, :comment, :string
  end
end
