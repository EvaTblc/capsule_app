class Event < ApplicationRecord
  belongs_to :user
  belongs_to :sender, class_name: "User", optional: true

  validates :title, presence: true

  geocoded_by :address
  after_validation :geocode, if: :address_changed_without_coordinates?

  # Événements de l'utilisateur dans un rayon autour de chez lui (tous s'il n'a pas d'adresse géocodée)
  def self.nearby_for(user, radius_km = 50)
    events = where(user: user)
    return events unless user.geocoded?

    # Coordonnées déjà stockées : pas d'appel à Mapbox
    events.near([ user.latitude, user.longitude ], radius_km)
  end

  private

  # Le scraper fournit déjà latitude/longitude : inutile de regéocoder l'adresse
  def address_changed_without_coordinates?
    will_save_change_to_address? && !(will_save_change_to_latitude? && will_save_change_to_longitude?)
  end
end
