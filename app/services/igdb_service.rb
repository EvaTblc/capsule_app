# Accès à IGDB (jeux vidéo) : jeton Twitch, requêtes, et lecture des jeux renvoyés.
# IGDB autorise et encourage le stockage local de ses données (FAQ de l'API).
class IgdbService
  CACHE_KEY = "igdb_access_token"

  # Champs demandés pour chaque jeu, en recherche comme pour le catalogue
  GAME_FIELDS = %w[name cover.url platforms.name summary genres.name first_release_date
                   alternative_names.name alternative_names.comment game_type total_rating_count
                   involved_companies.company.name involved_companies.developer
                   release_dates.date release_dates.release_region].freeze

  EUROPE_REGION = 1 # release_date_regions d'IGDB : 1 = europe

  # Types IGDB qui ne sont pas des jeux qu'on range dans une collection : DLC, mod, mise à jour, épisode, saison, fork, pack
  EXCLUDED_GAME_TYPES = [ 1, 5, 6, 7, 12, 13, 14 ].freeze

  def self.access_token
    token = Rails.cache.read(CACHE_KEY)
    if token.nil?
      token = fetch_new_token
      Rails.cache.write(CACHE_KEY, token, expires_in: 59.days)
    end
    token
  end

  # Réponse JSON d'IGDB, ou nil en cas d'erreur
  def self.post(endpoint, body, token = access_token)
    return nil unless token

    response = HTTP.timeout(10)
                   .headers("Client-ID" => Rails.application.credentials.dig(:igdb, :client_id),
                            "Authorization" => "Bearer #{token}")
                   .post("https://api.igdb.com/v4/#{endpoint}", body: body)
    # Token expiré ou révoqué : on l'oublie pour qu'un nouveau soit demandé au prochain appel
    Rails.cache.delete(CACHE_KEY) if response.code == 401
    response.status.success? ? JSON.parse(response.body.to_s) : nil
  rescue HTTP::Error, JSON::ParserError => e
    Rails.logger.warn("[igdb] #{endpoint} : #{e.class} #{e.message}")
    nil
  end

  # Jeux IGDB correspondant à name ([] si aucun), nil si IGDB est indisponible.
  # Deux recherches en parallèle : celle d'IGDB, qui ignore les titres français,
  # et une recherche dans les titres français officiels (« Pokémon Épée » → Pokémon Sword).
  # Les correspondances françaises passent en premier, sans doublon.
  def self.search(name, limit:)
    token = access_token
    return nil unless token

    # Les guillemets fermeraient la chaîne de la requête IGDB : on les retire
    query = name.delete('"\\')
    french_fields = GAME_FIELDS.map { |field| "game.#{field}" }.join(",")

    # On demande plus de résultats que nécessaire : une partie est écartée (mods, mises à jour...)
    fetch_limit = [ limit * 3, 15 ].max
    searches = [
      Thread.new { post("games", "fields #{GAME_FIELDS.join(',')}; search \"#{query}\"; limit #{fetch_limit};", token) },
      Thread.new do
        post("alternative_names",
             "fields #{french_fields}; where name ~ *\"#{query}\"* & comment = \"French title\"; limit #{fetch_limit};", token)
      end
    ]
    games, french_matches = searches.map(&:value)
    return nil if games.nil? # la recherche principale a échoué : IGDB indisponible

    french_games = (french_matches || []).filter_map { |match| match["game"] }
    rank(french_games + games, query).first(limit)
  end

  # « Super Mario: Odyssey » et « Super Mario Odyssey » doivent être considérés comme identiques
  def self.normalize_title(title)
    I18n.transliterate(title.to_s).downcase.gsub(/[^a-z0-9]+/, " ").strip
  end

  # Un jeu par son identifiant IGDB, nil s'il est inconnu ou si IGDB ne répond pas
  def self.game(id)
    post("games", "fields #{GAME_FIELDS.join(',')}; where id = #{Integer(id)};")&.first
  end

  # Titre français officiel référencé par IGDB, s'il existe
  def self.french_title(game)
    game["alternative_names"]&.find { |alt| alt["comment"] == "French title" }&.dig("name")
  end

  # Date de sortie européenne (la plus ancienne, toutes plateformes) : c'est celle des boîtes françaises.
  # À défaut, première sortie mondiale, souvent japonaise ou nord-américaine (Pokémon Diamant : 2006 au Japon, 2007 en Europe)
  def self.release_date(game)
    european = game["release_dates"]&.select { |release| release["release_region"] == EUROPE_REGION }
    timestamp = european&.filter_map { |release| release["date"] }&.min || game["first_release_date"]
    timestamp && Time.at(timestamp).utc.to_date
  end

  def self.developers(game)
    game["involved_companies"].to_a.select { |company| company["developer"] }.filter_map { |company| company.dig("company", "name") }
  end

  def self.fetch_new_token
    response = HTTP.timeout(10).post(
      "https://id.twitch.tv/oauth2/token",
      params: {
        client_id: Rails.application.credentials.dig(:igdb, :client_id),
        client_secret: Rails.application.credentials.dig(:igdb, :client_secret),
        grant_type: "client_credentials"
      }
    )
    JSON.parse(response.body.to_s)["access_token"]
  rescue => e
    Rails.logger.error("IGDB token fetch failed: #{e.message}")
    nil
  end
  # Écarte les mods & co, puis classe : titre identique à la recherche d'abord, puis les plus populaires.
  # Sans ça, « Super Mario Odyssey » renvoyait en premier un mod de fan (« Super Mario Odyssey F.L.U.D.D. »)
  def self.rank(games, query)
    wanted = normalize_title(query)
    games.uniq { |game| game["id"] }
         .reject { |game| EXCLUDED_GAME_TYPES.include?(game["game_type"]) }
         .sort_by do |game|
           titles = [ game["name"], french_title(game) ].compact.map { |title| normalize_title(title) }
           [ titles.include?(wanted) ? 0 : 1, -(game["total_rating_count"] || 0) ]
         end
  end

  # « private » ne s'applique pas aux méthodes def self. : il faut private_class_method
  private_class_method :fetch_new_token, :rank
end
