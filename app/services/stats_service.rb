class StatsService
  # { condition: { "Neuf" => 33, ... }, completed: 66 }  (pourcentages entiers)
  # completed : seulement pour les collections de jeux vidéo, nil s'il n'y a aucun jeu
  def self.call(collection)
    items = collection.items
    total = items.count

    # Un seul COUNT groupé au lieu de charger tous les items en mémoire
    results = {
      condition: items.group(:condition).count.transform_values { |count| count * 100 / total }
    }

    if collection.category == "video_games"
      games = VideoGameDetail.where(id: items.where(item_detailable_type: "VideoGameDetail").select(:item_detailable_id))
      games_count = games.count
      # Collection sans jeu : pas de pourcentage (avant : ZeroDivisionError)
      results[:completed] = games_count.zero? ? nil : games.where(completed: true).count * 100 / games_count
    end

    results
  end
end
