class UserCollection < ApplicationRecord
  belongs_to :user
  belongs_to :collection

  ROLES = %w[owner member]
  validates :role, inclusion: { in: ROLES }
  # Doublon de l'index unique en base, pour un message propre au lieu d'une exception
  validates :collection_id, uniqueness: { scope: :user_id }

  # Un membre retiré (ou qui part) ne laisse pas ses notes personnelles affichées aux autres membres.
  # Pas quand la suppression vient de la collection ou du compte : leurs notes sont alors supprimées avec eux
  after_destroy :detach_member_notes, unless: :destroyed_by_association

  private

  def detach_member_notes
    Note.where(user_id: user_id, collection_id: collection_id).update_all(collection_id: nil)
  end
end
