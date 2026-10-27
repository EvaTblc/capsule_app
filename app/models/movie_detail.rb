class MovieDetail < ApplicationRecord
  # Formats reconnus au scan (le champ reste libre dans le formulaire)
  FORMATS = [ "DVD", "Blu-ray", "Blu-ray 3D", "4K UHD", "VHS" ].freeze

  has_one :item, as: :item_detailable
end
