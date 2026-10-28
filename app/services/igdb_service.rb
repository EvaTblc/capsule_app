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
  # « private » ne s'applique pas aux méthodes def self. : il faut private_class_method
  private_class_method :fetch_new_token
end
