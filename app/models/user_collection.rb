class UserCollection < ApplicationRecord
  belongs_to :user
  belongs_to :collection

  ROLES = %w[owner member]
  validates :role, inclusion: { in: ROLES }
  
end
