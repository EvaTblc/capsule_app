class MovieDetail < ApplicationRecord
  has_one :item, as: :item_detailable
end
