class FigurineDetail < ApplicationRecord
  has_one :item, as: :item_detailable

  EDITION = ["Standard", "Limitée", "Exclusive", "Chase"].freeze
  CONDITION = ["Neuf", "Très bon état", "Bon état", "Correct", "Mauvais état"].freeze

  validates :edition, inclusion: { in: EDITION }
  validates :condition_box, inclusion: { in: CONDITION }
end
