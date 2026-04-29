class Item < ApplicationRecord
  belongs_to :item_detailable, polymorphic: true
  belongs_to :collection

  has_many_attached :images

  ITEM_TYPE_STYLES = {
  "BookDetail"      => "bg-emerald-50 shadow-emerald-100",
  "VideoGameDetail" => "bg-blue-50 shadow-blue-100",
  "MovieDetail"     => "bg-red-50 shadow-red-100",
  "MusicDetail"     => "bg-pink-50 shadow-pink-100",
  "FigurineDetail"  => "bg-orange-50 shadow-orange-100",
  "TcgDetail"       => "bg-green-50 shadow-green-100",
  "BoardGameDetail" => "bg-purple-50 shadow-purple-100"
  }

  TYPE_TO_ICON = {
    "BookDetail"      => "book",
    "VideoGameDetail" => "video_games",
    "MovieDetail"     => "movies",
    "MusicDetail"     => "music",
    "FigurineDetail"  => "figurines",
    "TcgDetail"       => "trading_cards",
    "BoardGameDetail" => "board_games"
  }
end
