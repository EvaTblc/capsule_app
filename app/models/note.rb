class Note < ApplicationRecord
  belongs_to :user
  belongs_to :sender, class_name: "User", optional: true
  belongs_to :collection, optional: true

  validates :title, presence: true
  validate :collection_accessible_by_user

  private

  # Empêche de rattacher une note (via un collection_id forgé) à une collection dont on n'est pas membre
  def collection_accessible_by_user
    return if collection.nil?
    errors.add(:collection, :invalid) unless user&.collections&.exists?(collection.id)
  end
end
