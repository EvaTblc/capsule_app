class VideoGameDetail < ApplicationRecord
  # Plateformes proposées dans le formulaire complet et dans l'ajout rapide
  PLATFORMS = [ "Switch", "Switch 2", "PS1", "PS2", "PS3", "PS4", "PS5", "Xbox", "Xbox 360", "Xbox One", "Xbox Series",
                "Nintendo DS", "Nintendo 3DS", "Wii", "Wii U", "Gamecube", "Autres" ].freeze

  has_one :item, as: :item_detailable

  validates :release_date, comparison: { greater_than: 1900 }, length: { is: 4 }, numericality: { only_integer: true }, allow_nil: true
end
