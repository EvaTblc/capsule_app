class VideoGameDetail < ApplicationRecord
  # Plateformes proposées dans le formulaire complet et dans l'ajout rapide
  PLATFORMS = [ "Switch", "Switch 2", "PS1", "PS2", "PS3", "PS4", "PS5", "Xbox", "Xbox 360", "Xbox One", "Xbox Series",
                "Nintendo DS", "Nintendo 3DS", "Wii", "Wii U", "Gamecube", "Autres" ].freeze

  # Nom de plateforme chez IGDB → plateforme de l'appli, pour pré-remplir le formulaire
  IGDB_PLATFORMS = {
    "Nintendo Switch" => "Switch", "Nintendo Switch 2" => "Switch 2",
    "PlayStation" => "PS1", "PlayStation 2" => "PS2", "PlayStation 3" => "PS3", "PlayStation 4" => "PS4", "PlayStation 5" => "PS5",
    "Xbox" => "Xbox", "Xbox 360" => "Xbox 360", "Xbox One" => "Xbox One", "Xbox Series X|S" => "Xbox Series",
    "Nintendo DS" => "Nintendo DS", "Nintendo 3DS" => "Nintendo 3DS", "Wii" => "Wii", "Wii U" => "Wii U", "Nintendo GameCube" => "Gamecube"
  }.freeze

  has_one :item, as: :item_detailable

  validates :release_date, comparison: { greater_than: 1900 }, length: { is: 4 }, numericality: { only_integer: true }, allow_nil: true
end
