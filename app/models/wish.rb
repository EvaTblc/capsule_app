class Wish < ApplicationRecord
  belongs_to :collection
  belongs_to :author, class_name: "User", optional: true
  belongs_to :product, optional: true

  validates :title, presence: true
  validates :max_price, numericality: { greater_than: 0 }, allow_nil: true
  validates :product_id, uniqueness: { scope: :collection_id }, allow_nil: true
  validate :author_is_member, on: :create

  # Ce que user peut consulter : les souhaits de ses collections, plus ceux ajoutés par ses amis
  # qui l'acceptent (en lecture seule). Pas les collections publiques : ça contournerait l'interrupteur
  scope :visible_to, lambda { |user|
    where(collection_id: user.collections.select(:id))
      .or(where(author_id: user.accepted_friends.where(wishes_visible_to_friends: true).select(:id)))}

  private

  # Empêche d'ajouter un souhait (via un collection_id forgé) dans une collection dont on n'est pas membre
  def author_is_member
    return if author.nil? || collection.nil?
    errors.add(:collection, :invalid) unless collection.member?(author)
  end
end
