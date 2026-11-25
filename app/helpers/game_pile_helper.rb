module GamePileHelper
  # Jeux de la collection reliés au catalogue, avec leurs plateformes : { igdb_id => ["Switch", "PS4"] }
  def owned_games(collection)
    collection.items.where(item_detailable_type: "VideoGameDetail")
              .joins(:product)
              .joins("JOIN video_game_details ON video_game_details.id = items.item_detailable_id")
              .pluck("products.igdb_id", "video_game_details.platform")
              .group_by(&:first)
              .transform_values { |rows| rows.map(&:last).compact_blank.uniq }
  end
end
