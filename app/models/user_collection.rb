class UserCollection < ApplicationRecord
  belongs_to :user
  belongs_to :collection

  ROLES = %w[owner member]
  validates :role, inclusion: { in: ROLES }
  # Doublon de l'index unique en base, pour un message propre au lieu d'une exception
  validates :collection_id, uniqueness: { scope: :user_id }
end
