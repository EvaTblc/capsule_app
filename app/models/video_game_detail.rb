class VideoGameDetail < ApplicationRecord
  # Boutons du formulaire complet et de l'ajout rapide : les plateformes actuelles
  MAIN_PLATFORMS = [ "Switch 2", "Switch", "PS5", "Xbox Series", "Nintendo 3DS" ].freeze

  # Liste déroulante « Autres plateformes », par marque, de la plus récente à la plus ancienne
  PLATFORM_GROUPS = {
    "Nintendo" => [ "Nintendo DS", "Wii U", "Wii", "Gamecube", "Nintendo 64", "Super Nintendo",
                    "Game Boy Advance", "Game Boy Color", "Game Boy" ],
    "PlayStation" => [ "PS4", "PS3", "PS2", "PS1" ],
    "Xbox" => [ "Xbox One", "Xbox 360", "Xbox" ],
    "Sega" => [ "Mega Drive", "Game Gear" ],
    "Autres" => [ "PC", "Atari", "Autres" ]
  }.freeze

  # Toutes les plateformes (boutons + liste), calculée pour que les trois listes ne divergent jamais :
  # nettoyage des données, valeurs proposées à Claude au scan, validation
  PLATFORMS = (MAIN_PLATFORMS + PLATFORM_GROUPS.values.flatten).uniq.freeze

  # Nom de plateforme chez IGDB → plateforme de l'appli, pour pré-remplir le formulaire
  IGDB_PLATFORMS = {
    "Nintendo Switch" => "Switch", "Nintendo Switch 2" => "Switch 2",
    "PlayStation" => "PS1", "PlayStation 2" => "PS2", "PlayStation 3" => "PS3", "PlayStation 4" => "PS4", "PlayStation 5" => "PS5",
    "Xbox" => "Xbox", "Xbox 360" => "Xbox 360", "Xbox One" => "Xbox One", "Xbox Series X|S" => "Xbox Series",
    "Nintendo DS" => "Nintendo DS", "Nintendo 3DS" => "Nintendo 3DS", "Wii" => "Wii", "Wii U" => "Wii U", "Nintendo GameCube" => "Gamecube",
    "PC (Microsoft Windows)" => "PC",
    "Game Boy" => "Game Boy", "Game Boy Color" => "Game Boy Color", "Game Boy Advance" => "Game Boy Advance",
    "Nintendo 64" => "Nintendo 64", "Sega Game Gear" => "Game Gear", "Sega Mega Drive/Genesis" => "Mega Drive",
    "Super Nintendo Entertainment System" => "Super Nintendo", "Super Famicom" => "Super Nintendo",
    "Atari 2600" => "Atari", "Atari 5200" => "Atari", "Atari 7800" => "Atari", "Atari Jaguar" => "Atari", "Atari Lynx" => "Atari"
  }.freeze

  has_one :item, as: :item_detailable

  validates :release_date, comparison: { greater_than: 1900 }, length: { is: 4 }, numericality: { only_integer: true }, allow_nil: true
end
