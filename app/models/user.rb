class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
  :recoverable, :rememberable, :validatable,
  :omniauthable, omniauth_providers: [:google_oauth2]

  has_many :user_collections, dependent: :destroy
  has_many :collections, through: :user_collections
  has_many :notes
  has_many :events

  has_many :sent_friendships, class_name: "Friendship", foreign_key: :requester_id
  has_many :received_friendships, class_name: "Friendship", foreign_key: :receiver_id

  has_many :friends, through: :sent_friendships, source: :receiver
  has_many :pending_requests, through: :received_friendships, source: :requester

  geocoded_by :address
  after_validation :geocode, if: :will_save_change_to_address?

  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.email = auth.info.email
      user.password = Devise.friendly_token[0, 20]
      user.avatar_url = auth.info.image
    end
  end

  def all_friends
    sent = Friendship.where(requester: self, status: "accepted").map(&:receiver)
    received = Friendship.where(receiver: self, status: "accepted").map(&:requester)
    sent + received
  end
end
