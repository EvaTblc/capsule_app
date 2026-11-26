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

  # Jeux cherchés par mes amis (mêmes règles que leur page de souhaits : Wish.visible_to), pour l'alerte
  # « lou cherche ce jeu ! » : igdb_id => [{ name, platform, max_price }]. Sans les souhaits de cette collection :
  # un ami qui en est membre y déclenche déjà « Tu le cherches ! »
  def friends_wanted_games(collection, user)
    Wish.visible_to(user).where(author_id: user.accepted_friends.select(:id)).where.not(collection_id: collection.id)
        .joins(:product, :author)
        .pluck("products.igdb_id", "users.email", "wishes.platform", "wishes.max_price")
        .group_by(&:first)
        .transform_values do |rows|
          rows.map { |_, email, platform, price| { name: email.split("@").first, platform: platform.presence, max_price: price && euros(price) } }
        end
  end
end
