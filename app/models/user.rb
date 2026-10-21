class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
  :recoverable, :rememberable, :validatable,
  :omniauthable, omniauth_providers: [:google_oauth2]

  # prepend : doit passer AVANT le dependent: :destroy ci-dessous, qui efface les rôles de propriétaire
  before_destroy :hand_over_owned_collections, prepend: true

  has_many :user_collections, dependent: :destroy
  has_many :collections, through: :user_collections
  has_many :items, through: :collections
  has_many :notes, dependent: :destroy
  has_many :events, dependent: :destroy
  # Notes/events partagés à des amis : on les garde chez l'ami, sans expéditeur
  has_many :sent_notes, class_name: "Note", foreign_key: :sender_id, dependent: :nullify
  has_many :sent_events, class_name: "Event", foreign_key: :sender_id, dependent: :nullify

  has_many :sent_friendships, class_name: "Friendship", foreign_key: :requester_id, dependent: :destroy
  has_many :received_friendships, class_name: "Friendship", foreign_key: :receiver_id, dependent: :destroy

  geocoded_by :address
  after_validation :geocode, if: :will_save_change_to_address?

  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.email = auth.info.email
      user.password = Devise.friendly_token[0, 20]
      user.avatar_url = auth.info.image
    end
  end

  # Amis acceptés, dans les deux sens. Relation (et non tableau) : on peut chaîner .find, .where...
  def accepted_friends
    User.where(id: Friendship.accepted.where(requester: self).select(:receiver_id))
        .or(User.where(id: Friendship.accepted.where(receiver: self).select(:requester_id)))
  end

  private

  # À la suppression du compte, chaque collection dont il est propriétaire est transmise
  # au plus ancien autre membre ; sans autre membre, elle est supprimée (avec ses items)
  def hand_over_owned_collections
    user_collections.where(role: "owner").includes(:collection).find_each do |membership|
      collection = membership.collection
      others = collection.user_collections.where.not(user_id: id)
      next if others.where(role: "owner").exists? # un autre propriétaire existe déjà

      successor = others.order(:created_at).first
      successor ? successor.update!(role: "owner") : collection.destroy!
    end
  end
end
