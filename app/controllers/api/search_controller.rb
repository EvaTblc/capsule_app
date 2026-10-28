class Api::SearchController < ApplicationController
  class ExternalApiError < StandardError; end

  before_action :authenticate_user!
  before_action :require_numeric_id, only: [ :movie_detail, :music_detail ]
  # Scans : UPCitemdb (et Claude pour les jeux). Le scan de livre passe par la recherche Google Books, gratuite
  before_action :require_paid_features, only: [ :game_barcode, :movie_barcode ]
  rate_limit to: 20, within: 1.minute, only: [ :game_barcode, :search_game ]

  # Filet de sécurité commun à toutes les actions : le détail part dans les logs,
  # le navigateur ne reçoit qu'un message générique
  rescue_from StandardError, with: :render_api_error

  def game_barcode
    ean = params[:ean].to_s.strip
    return render json: { error: "Barcode manquant" }, status: :unprocessable_entity if ean.blank?

    # Étape 1 : la boîte (déjà connue, sinon BnF → UPCitemdb → EAN-DB), étape 2 : les noms du jeu
    box = BarcodeService.lookup(ean, kind: :game)
    return render json: { error: "Jeu non trouvé", fallback: true }, status: :not_found unless box
    return render_other_kind(box, :game) unless box.game?

    names = scanned_names(box)
    Rails.logger.info("[game_barcode] #{box.source} : #{box.raw_title} → #{names.inspect}")

    # Étape 3 : IGDB par nom (titre principal, puis titre français), en écartant les jeux dont le titre ne correspond pas
    game = nil
    names.each do |name|
      games = igdb_search(name, limit: 3)
      return render json: { error: "IGDB indisponible" }, status: :service_unavailable if games.nil?

      game = games.find { |candidate| matching_title?(name, igdb_titles(candidate)) }
      break if game
    end
    return render json: { error: "Jeu non trouvé", fallback: true }, status: :not_found unless game

    summary = begin
      TranslationService.translate_batch([ game["summary"].to_s ]).first
    rescue TranslationService::Error => e
      Rails.logger.warn("[game_barcode] Traduction impossible, résumé laissé en anglais : #{e.message}")
      game["summary"]
    end

    # La boîte dit sur quelle plateforme est le jeu possédé, et son édition ; le code-barres est gardé avec l'item
    json = igdb_game_json(game, summary: summary)
    render json: json.merge(platform: box.platform || json[:platform], edition: box.edition, barcode: box.barcode)
  end

  def movie_barcode
    ean = params[:ean].to_s.strip
    return render json: { error: "Barcode manquant" }, status: :unprocessable_entity if ean.blank?

    # Étape 1 : la boîte (déjà connue, sinon BnF → UPCitemdb → EAN-DB), étape 2 : les titres du film
    # (TMDB ne sait pas chercher par EAN : sans titre, on passe en recherche manuelle)
    box = BarcodeService.lookup(ean, kind: :movie)
    return render json: { error: "Film non trouvé", fallback: true }, status: :not_found unless box
    return render_other_kind(box, :movie) unless box.movie?

    names = scanned_names(box)
    Rails.logger.info("[movie_barcode] #{box.source} : #{box.raw_title} → #{names.inspect}")

    # Étape 3 : TMDB par titre (original, puis français), en écartant les films dont le titre ne correspond pas
    movie = nil
    names.each do |name|
      results = tmdb_get("search/movie", query: name, language: "fr-FR")["results"] || []
      movie = results.first(3).find { |candidate| matching_title?(name, [ candidate["title"], candidate["original_title"] ]) }
      break if movie
    end
    return render json: { error: "Film non trouvé", fallback: true }, status: :not_found unless movie

    # Étape 4 : Détails + réalisateur
    detail_data = tmdb_get("movie/#{movie['id']}", language: "fr-FR")
    credits_data = tmdb_get("movie/#{movie['id']}/credits")

    director = credits_data["crew"]&.find { |p| p["job"] == "Director" }&.dig("name")
    studio = detail_data["production_companies"]&.map { |c| c["name"] }&.join(", ")
    poster_url = movie["poster_path"] ? "https://image.tmdb.org/t/p/w500#{movie['poster_path']}" : nil

    render json: {
      id: movie["id"],
      title: movie["title"],
      year: movie["release_date"]&.split("-")&.first&.to_i,
      description: movie["overview"],
      director: director,
      studio: studio,
      poster_url: poster_url,
      format: box.format,
      edition: box.edition,
      barcode: box.barcode
    }
  end

  def search_game
    query = params[:query].to_s.strip
    return render json: { error: "Query vide" }, status: :unprocessable_entity if query.blank?

    games = igdb_search(query, limit: 10)
    return render json: { error: "IGDB indisponible" }, status: :service_unavailable if games.nil?

    render json: { games: games.map { |game| igdb_game_json(game, summary: game["summary"]) } }
  end

  def book
    query = params[:query].to_s.strip
    return render json: [] if query.blank?

    search_query = query.match?(/^\d{10,13}$/) ? "isbn:#{query}" : query
    Rails.logger.info("[book] search_query: #{search_query}")

    data = get_json("https://www.googleapis.com/books/v1/volumes", params: {
      q: search_query,
      key: Rails.application.credentials.dig(:google, :books_api_key),
      maxResults: 5,
      langRestrict: "fr"
    })

    results = data["items"]&.map do |item|
      info = item["volumeInfo"]
      {
        id: item["id"],
        title: info["title"],
        author: info["authors"]&.join(", "),
        publisher: info["publisher"],
        pages: info["pageCount"],
        genre: info["categories"]&.join(", "),
        isbn: info["industryIdentifiers"]&.find { |i| i["type"] == "ISBN_13" }&.dig("identifier"),
        description: info["description"]
      }
    end
    render json: results || []
  end

  def movie
    query = params[:query].to_s.strip
    return render json: [] if query.blank?

    data = tmdb_get("search/movie", query: query, language: "fr-FR")

    results = data["results"]&.first(5)&.map do |movie|
      {
        id: movie["id"],
        title: movie["title"],
        year: movie["release_date"]&.split("-")&.first,
        description: movie["overview"]
      }
    end

    render json: results || []
  end

  def movie_detail
    data = tmdb_get("movie/#{params[:id]}", language: "fr-FR")
    # Crédits pour le réalisateur
    credits_data = tmdb_get("movie/#{params[:id]}/credits")

    director = credits_data["crew"]&.find { |p| p["job"] == "Director" }&.dig("name")

    render json: {
      director: director,
      studio: data["production_companies"]&.map { |c| c["name"] }&.join(", ")
    }
  end

  def music
    query = params[:query].to_s.strip
    return render json: [] if query.blank?

    data = discogs_get("database/search", q: query, type: "release", per_page: 5)

    results = data["results"]&.map do |release|
      {
        id: release["id"],
        title: release["title"],
        year: release["year"],
        label: release["label"]&.first,
        format: release["format"]&.first,
        genre: release["genre"]&.first
      }
    end

    render json: results || []
  end

  def music_detail
    data = discogs_get("releases/#{params[:id]}")

    render json: {
      artist: data["artists"]&.map { |a| a["name"] }&.join(", "),
      description: data["notes"]
    }
  end

  private

  # GET d'une API JSON externe, avec timeout.
  # Lève ExternalApiError si l'API répond en erreur (clé invalide, quota, 500...)
  def get_json(url, params: {}, headers: {})
    response = HTTP.timeout(10).headers(headers).get(url, params: params)
    raise ExternalApiError, "#{URI(url).host} a répondu #{response.status}" unless response.status.success?

    JSON.parse(response.body.to_s)
  end

  def tmdb_get(path, **params)
    get_json("https://api.themoviedb.org/3/#{path}",
             params: params.merge(api_key: Rails.application.credentials.dig(:tmdb, :api_key)))
  end

  def discogs_get(path, **params)
    get_json("https://api.discogs.com/#{path}",
             params: params.merge(token: Rails.application.credentials.dig(:discogs, :token)),
             headers: { "User-Agent" => "CapsuleApp/1.0" }) # Discogs refuse les requêtes sans User-Agent
  end

  # L'id est inséré dans l'URL de l'API externe : on n'accepte que des chiffres
  def require_numeric_id
    render json: { error: "Identifiant invalide" }, status: :bad_request unless params[:id].to_s.match?(/\A\d+\z/)
  end

  def render_api_error(error)
    Rails.logger.error("[api/search##{action_name}] #{error.class}: #{error.message}")
    # 502 = une API externe a échoué ; 500 = bug chez nous
    external = error.is_a?(ExternalApiError) || error.is_a?(HTTP::Error) || error.is_a?(JSON::ParserError)
    render json: { error: "Recherche indisponible" }, status: external ? :bad_gateway : :internal_server_error
  end

  # Noms à chercher pour une boîte (extraits une fois par Claude, puis gardés avec elle).
  # S'il ne répond pas : nom nettoyé par règles (moins fiable, mais mieux que rien), non gardé
  def scanned_names(box)
    BarcodeService.names_for(box)
  rescue BarcodeService::Error => e
    Rails.logger.warn("[#{box.kind}_barcode] Claude indisponible, nettoyage par règles : #{e.message}")
    [ box.game? ? clean_game_title(box.raw_title) : clean_movie_title(box.raw_title) ]
  end

  KIND_LABELS = { "game" => "un jeu vidéo", "movie" => "un film", "book" => "un livre" }.freeze

  # Code-barres d'un autre type que le formulaire (livre scanné depuis le formulaire jeu...) :
  # on le dit, au lieu de pré-remplir avec n'importe quoi
  def render_other_kind(box, expected)
    render json: { error: "Ce code-barres correspond à #{KIND_LABELS[box.kind]}, pas à #{KIND_LABELS[expected.to_s]}.",
                   fallback: true, other_kind: box.kind }, status: :not_found
  end

  # Mots qui ne distinguent pas un titre d'un autre
  TITLE_FILLER_WORDS = %w[the a an of and version edition le la les l de du des et].freeze

  # Garde-fou des scans : tous les mots significatifs du nom cherché doivent figurer dans l'un des titres trouvés.
  # « Pokemon Diamond » refuse « Pokémon White Version 2 » : mieux vaut « introuvable » qu'un mauvais jeu ajouté en silence
  def matching_title?(wanted, titles)
    wanted_words = significant_words(wanted)
    titles.compact.any? { |title| wanted_words.subset?(significant_words(title)) }
  end

  def significant_words(title)
    normalize_game_title(title).split.to_set - TITLE_FILLER_WORDS
  end

  # Titre d'origine et titres alternatifs (français, européen...) d'un jeu IGDB
  def igdb_titles(game)
    [ game["name"], *game["alternative_names"]&.map { |alt| alt["name"] } ]
  end

  # Liste de jeux IGDB ([] si aucun résultat), nil si IGDB est indisponible
  IGDB_GAME_FIELDS = %w[name cover.url platforms.name summary genres.name first_release_date
                        alternative_names.name alternative_names.comment game_type total_rating_count
                        involved_companies.company.name involved_companies.developer
                        release_dates.date release_dates.release_region].freeze

  # Types IGDB qui ne sont pas des jeux qu'on range dans une collection : DLC, mod, mise à jour, épisode, saison, fork, pack
  IGDB_EXCLUDED_GAME_TYPES = [ 1, 5, 6, 7, 12, 13, 14 ].freeze

  # Jeux IGDB correspondant à name ([] si aucun), nil si IGDB est indisponible.
  # Deux recherches en parallèle : celle d'IGDB, qui ignore les titres français,
  # et une recherche dans les titres français officiels (« Pokémon Épée » → Pokémon Sword).
  # Les correspondances françaises passent en premier, sans doublon.
  def igdb_search(name, limit:)
    token = IgdbService.access_token
    return nil unless token

    # Les guillemets fermeraient la chaîne de la requête IGDB : on les retire
    query = name.delete('"\\')
    french_fields = IGDB_GAME_FIELDS.map { |field| "game.#{field}" }.join(",")

    # On demande plus de résultats que nécessaire : une partie est écartée (mods, mises à jour...)
    fetch_limit = [ limit * 3, 15 ].max
    searches = [
      Thread.new { igdb_post("games", "fields #{IGDB_GAME_FIELDS.join(',')}; search \"#{query}\"; limit #{fetch_limit};", token) },
      Thread.new do
        igdb_post("alternative_names",
                  "fields #{french_fields}; where name ~ *\"#{query}\"* & comment = \"French title\"; limit #{fetch_limit};", token)
      end
    ]
    games, french_matches = searches.map(&:value)
    return nil if games.nil? # la recherche principale a échoué : IGDB indisponible

    french_games = (french_matches || []).filter_map { |match| match["game"] }
    rank_igdb_games(french_games + games, query).first(limit)
  end

  # Écarte les mods & co, puis classe : titre identique à la recherche d'abord, puis les plus populaires.
  # Sans ça, « Super Mario Odyssey » renvoyait en premier un mod de fan (« Super Mario Odyssey F.L.U.D.D. »)
  def rank_igdb_games(games, query)
    wanted = normalize_game_title(query)
    games.uniq { |game| game["id"] }
         .reject { |game| IGDB_EXCLUDED_GAME_TYPES.include?(game["game_type"]) }
         .sort_by do |game|
           titles = [ game["name"], french_title(game) ].compact.map { |title| normalize_game_title(title) }
           [ titles.include?(wanted) ? 0 : 1, -(game["total_rating_count"] || 0) ]
         end
  end

  # « Super Mario: Odyssey » et « Super Mario Odyssey » doivent être considérés comme identiques
  def normalize_game_title(title)
    I18n.transliterate(title.to_s).downcase.gsub(/[^a-z0-9]+/, " ").strip
  end

  # Réponse JSON d'IGDB, ou nil en cas d'erreur
  def igdb_post(endpoint, body, token)
    response = HTTP.timeout(10)
                   .headers("Client-ID" => Rails.application.credentials.dig(:igdb, :client_id),
                            "Authorization" => "Bearer #{token}")
                   .post("https://api.igdb.com/v4/#{endpoint}", body: body)
    # Token expiré ou révoqué : on l'oublie pour qu'un nouveau soit demandé au prochain appel
    Rails.cache.delete(IgdbService::CACHE_KEY) if response.code == 401
    response.status.success? ? JSON.parse(response.body.to_s) : nil
  rescue HTTP::Error, JSON::ParserError => e
    Rails.logger.warn("[igdb] #{endpoint} : #{e.class} #{e.message}")
    nil
  end

  IGDB_EUROPE_REGION = 1 # release_date_regions d'IGDB : 1 = europe

  # Date de sortie européenne (la plus ancienne, toutes plateformes) : c'est celle des boîtes françaises.
  # À défaut, première sortie mondiale, souvent japonaise ou nord-américaine (Pokémon Diamant : 2006 au Japon, 2007 en Europe)
  def release_date_of(game)
    european = game["release_dates"]&.select { |release| release["release_region"] == IGDB_EUROPE_REGION }
    timestamp = european&.filter_map { |release| release["date"] }&.min || game["first_release_date"]
    timestamp && Time.at(timestamp).utc.to_date
  end

  # Titre français officiel référencé par IGDB, s'il existe
  def french_title(game)
    game["alternative_names"]&.find { |alt| alt["comment"] == "French title" }&.dig("name")
  end

  def igdb_game_json(game, summary:)
    cover_url = game.dig("cover", "url") ? "https:#{game['cover']['url'].gsub('t_thumb', 't_cover_big')}" : nil
    release_date = release_date_of(game)
    platforms = game["platforms"]&.map { |p| p["name"] }&.join(", ")
    genres = game["genres"]&.map { |g| g["name"] }&.join(", ")
    french_name = french_title(game)
    developers = game["involved_companies"]&.select { |company| company["developer"] }&.filter_map { |company| company.dig("company", "name") }
    # Plateforme de l'appli, seulement si le jeu n'existe que sur une seule : sinon c'est à l'utilisateur de choisir
    app_platforms = game["platforms"]&.filter_map { |p| VideoGameDetail::IGDB_PLATFORMS[p["name"]] }&.uniq || []

    {
      id: game["id"],
      # Titre français officiel quand IGDB le connaît, sinon titre d'origine
      name: french_name || game["name"],
      # Titre d'origine, affiché en petit pour reconnaître le jeu (nil s'il est identique)
      original_name: (game["name"] if french_name && french_name != game["name"]),
      cover_url: cover_url,
      platforms: platforms,
      platform: (app_platforms.first if app_platforms.one?),
      developer: developers.presence&.join(", "),
      release_date: release_date&.year,
      summary: summary,
      genres: genres,
      metadata: {
        platforms: platforms,
        summary: summary,
        cover_url: cover_url,
        genres: genres,
        release_date: release_date&.to_s
      }
    }
  end

  def clean_movie_title(title)
    # D'abord le format (« - Blu-ray », « (DVD) »...), en mots entiers pour ne pas couper « Spider-Man »
    title = title.gsub(/\s*[-(\[]?\s*\b(dvd|blu-ray|blu ray|4k|uhd|region \d|uk import|fr import)\b\s*[)\]]?/i, "")
    title = title.gsub(/\s*(\[.*?\]|\(.*?import.*?\))/i, "")
    # Puis un éventuel préfixe éditeur (« Warner - Inception »)
    title = title.sub(/\A[^-]+\s+-\s+/, "") if title.include?(" - ")
    title.strip
  end

  # « Switch » seul n'y figure pas : il fait partie de titres (« Switch Sports »)
  GAME_PLATFORMS = [
    "Nintendo Switch 2", "Nintendo Switch", "PlayStation 5", "PlayStation 4", "PS5", "PS4",
    "Xbox Series X", "Xbox Series S", "Xbox One", "PC", "Steam", "Nintendo 3DS", "Wii U"
  ].freeze

  # Repli quand Claude ne répond pas. Titre UPCitemdb → nom de jeu cherchable sur IGDB, ex. :
  # « Mario Kart 8 Deluxe - Nintendo Switch Video Game - European Version (International Version) » → « Mario Kart 8 Deluxe »
  def clean_game_title(title)
    clean = title.gsub(/\(.*?\)|\[.*?\]/, " ")           # (International Version), [Import]...
    clean = clean.split(/\s+[-–:|]\s+/).first.to_s         # ce qui suit un séparateur espacé : console, édition, région
    GAME_PLATFORMS.each do |platform|
      # Jamais en début de titre : « Nintendo Switch Sports » doit rester intact
      clean = clean.gsub(/(?<=\S)\s+#{Regexp.escape(platform)}(?![\w-])/i, " ")
    end
    clean = clean.gsub(/\b(video game|import region free)\b/i, " ")
    clean.gsub(/(\w) s (?=\w)/, "\\1's ").squeeze(" ").strip # « Luigi s Mansion » → « Luigi's Mansion »
  end
end
