class AddSenderToNotesAndEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :sender_id, :integer
    add_column :notes, :sender_id, :integer
  end
end
