class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
  :recoverable, :rememberable, :validatable,
  :omniauthable, omniauth_providers: [ :google_oauth2 ]

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
  # Boîtes du catalogue reliées à une œuvre par ce compte ; la base vide la référence si le compte est supprimé
  has_many :confirmed_barcode_products, class_name: "BarcodeProduct", foreign_key: :confirmed_by_id, inverse_of: :confirmed_by

  enum :role, { admin: "admin", premium: "premium", free: "free" }, validate: true

  geocoded_by :address
  after_validation :geocode, if: :will_save_change_to_address?

  # Vrai quand from_omniauth vient de relier Google à un compte e-mail existant (pour prévenir l'utilisatrice)
  attr_accessor :just_linked_to_google

  # Connexion Google :
  # 1. compte déjà relié à ce compte Google → connexion
  # 2. compte e-mail existant avec la même adresse, vérifiée par Google → on le relie
  # 3. sinon → nouveau compte
  # Renvoie un utilisateur non enregistré, avec une erreur, si la connexion doit être refusée.
  def self.from_omniauth(auth)
    user = find_by(provider: auth.provider, uid: auth.uid)
    return user if user

    # La gem ne remplit info.email que si Google a vérifié l'adresse. On le revérifie explicitement :
    # relier un compte sur une adresse non vérifiée permettrait à n'importe qui de s'en emparer.
    email = auth.info.email.to_s.downcase.strip
    unless email.present? && auth.info.email_verified
      return new.tap { |refused| refused.errors.add(:base, :google_unverified) }
    end

    user = find_by(email: email)
    return create_from_google(auth, email) unless user

    if user.uid.present?
      # Déjà relié à un AUTRE compte Google : on ne remplace pas le lien en silence
      return new.tap { |refused| refused.errors.add(:base, :google_other_account) }
    end

    # Le mot de passe est remplacé : quelqu'un a pu créer ce compte avec cette adresse avant sa vraie
    # propriétaire, que Google vient d'authentifier (pré-détournement de compte). Changer le mot de passe
    # ferme aussi toute session ouverte avec l'ancien (Devise lie les sessions au mot de passe).
    user.update!(provider: auth.provider, uid: auth.uid, password: Devise.friendly_token[0, 20],
                 avatar_url: user.avatar_url.presence || auth.info.image)
    user.just_linked_to_google = true
    user
  end

  def self.create_from_google(auth, email)
    create(provider: auth.provider, uid: auth.uid, email: email,
           password: Devise.friendly_token[0, 20], avatar_url: auth.info.image)
  end

  # Amis acceptés, dans les deux sens. Relation (et non tableau) : on peut chaîner .find, .where...
  def accepted_friends
    User.where(id: Friendship.accepted.where(requester: self).select(:receiver_id))
        .or(User.where(id: Friendship.accepted.where(receiver: self).select(:requester_id)))
  end

  # Vérifie le role pour les features payantes (IA/Scan)
  def paid_features?
    admin? || premium?
  end

  private

  # Les e-mails Devise (mot de passe oublié...) partent en tâche de fond via Solid Queue :
  # la page répond tout de suite, et un échec d'envoi est réessayé au lieu de planter la requête
  def send_devise_notification(notification, *args)
    devise_mailer.send(notification, self, *args).deliver_later
  end

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
