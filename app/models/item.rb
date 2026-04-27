class Item < ApplicationRecord
  belongs_to :item_detailable, polymorphic: true
  belongs_to :collection
end
