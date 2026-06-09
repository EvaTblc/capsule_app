class Event < ApplicationRecord
  belongs_to :user
  belongs_to :sender, class_name: "User", optional: true
  
  geocoded_by :address
  after_validation :geocode, if: :will_save_change_to_address?
end
