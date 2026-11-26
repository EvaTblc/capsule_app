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

  # Jeux cherchés (souhaits reliés au catalogue) : igdb_id => [{ id, platform, max_price }], pour l'alerte « Tu le cherches ! »
  def wanted_games(collection)
    collection.wishes.joins(:product)
              .pluck("products.igdb_id", "wishes.id", "wishes.platform", "wishes.max_price")
              .group_by(&:first)
              .transform_values do |rows|
                rows.map { |_, id, platform, price| { id: id, platform: platform.presence, max_price: price && euros(price) } }
              end
  end
end
