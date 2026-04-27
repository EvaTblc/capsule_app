class Collection < ApplicationRecord
  has_many :items
  has_many :user_collections
  has_many :users, through: :user_collections

  CATEGORIES = %w[comics movies music video_games figurines trading_cards board_games books mixed other]

  validates :title, presence: true
  validates :category, inclusion: { in: CATEGORIES }
end
