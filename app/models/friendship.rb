class Friendship < ApplicationRecord
  belongs_to :requester, class_name: "User"
  belongs_to :receiver, class_name: "User"

  enum :status, { pending: "pending", accepted: "accepted", rejected: "rejected" }

  validates :receiver_id, comparison: { other_than: :requester_id }
  validate :pair_not_already_linked, on: :create

  # L'amitié entre deux utilisateurs, dans un sens ou dans l'autre
  scope :between, ->(user_a, user_b) {
    where(requester: user_a, receiver: user_b).or(where(requester: user_b, receiver: user_a))
  }

  private

  # Doublon de l'index unique en base, pour avoir un message propre au lieu d'une exception
  def pair_not_already_linked
    errors.add(:base, :taken) if Friendship.between(requester, receiver).exists?
  end
end
