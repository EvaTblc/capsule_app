class VideoGameDetail < ApplicationRecord
  has_one :item, as: :item_detailable

  validates :release_date, comparison: { greater_than: 1900 }, length: { is: 4 }, numericality: { only_integer: true }, allow_nil: true
end
