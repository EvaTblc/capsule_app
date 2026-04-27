class Collection < ApplicationRecord
  has_many :items
  has_many :user_collections
  has_many :users, through: :user_collections

  CATEGORIES = %w[comics movies music video_games figurines trading_cards board_games books mixed other]
  CATEGORY_STYLES = {
  "comics"        => "bg-yellow-50 shadow-yellow-100",
  "movies"        => "bg-red-50 shadow-red-100",
  "music"         => "bg-pink-50 shadow-pink-100",
  "video_games"   => "bg-blue-50 shadow-blue-100",
  "figurines"     => "bg-orange-50 shadow-orange-100",
  "trading_cards" => "bg-green-50 shadow-green-100",
  "board_games"   => "bg-purple-50 shadow-purple-100",
  "books"         => "bg-emerald-50 shadow-emerald-100",
  "mixed"         => "bg-purple-50 shadow-violet-100",
  "other"         => "bg-gray-50 shadow-gray-100"
  }

  validates :title, presence: true
  validates :category, inclusion: { in: CATEGORIES }
end
