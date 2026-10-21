class Api::SearchController < ApplicationController
  class ExternalApiError < StandardError; end

  before_action :authenticate_user!
  before_action :require_numeric_id, only: [ :movie_detail, :music_detail ]
  rate_limit to: 20, within: 1.minute, only: [ :game_barcode, :search_game ]

  # Filet de sécurité commun à toutes les actions : le détail part dans les logs,
  # le navigateur ne reçoit qu'un message générique
  rescue_from StandardError, with: :render_api_error

  def game_barcode
    ean = params[:ean].to_s.strip
    return render json: { error: "Barcode manquant" }, status: :unprocessable_entity if ean.blank?

    # Étape 1 : UPCitemdb pour récupérer le nom du produit
    product_title = upc_product_title(ean)
    return render json: { error: "Jeu non trouvé", fallback: true }, status: :not_found unless product_title

    game_name = clean_game_title(product_title)
    Rails.logger.info("[game_barcode] UPCitemdb: #{product_title} → #{game_name}")

    # Étape 2 : IGDB par nom
    games = igdb_search(game_name, limit: 1)
    return render json: { error: "IGDB indisponible" }, status: :service_unavailable if games.nil?

    game = games.first
    return render json: { error: "Jeu non trouvé", fallback: true }, status: :not_found unless game

    summary = begin
      TranslationService.translate_batch([ game["summary"].to_s ]).first
    rescue TranslationService::Error => e
      Rails.logger.warn("[game_barcode] Traduction impossible, résumé laissé en anglais : #{e.message}")
      game["summary"]
    end

    render json: igdb_game_json(game, summary: summary)
  end

  def movie_barcode
    ean = params[:ean].to_s.strip
    return render json: { error: "Barcode manquant" }, status: :unprocessable_entity if ean.blank?

    # Étape 1 : UPCitemdb pour récupérer le nom du produit
    # (ni OMDb ni TMDB ne savent chercher par EAN : sans UPCitemdb, on passe en recherche manuelle)
    product_title = upc_product_title(ean)
    return render json: { error: "Film non trouvé", fallback: true }, status: :not_found unless product_title

    movie_name = clean_movie_title(product_title)
    Rails.logger.info("[movie_barcode] UPCitemdb: #{product_title} → #{movie_name}")

    # Étape 2 : TMDB par titre
    movie = tmdb_get("search/movie", query: movie_name, language: "fr-FR")["results"]&.first
    return render json: { error: "Film non trouvé", fallback: true }, status: :not_found unless movie

    # Étape 3 : Détails + réalisateur
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
      poster_url: poster_url
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

  # Titre du produit chez UPCitemdb, nil si inconnu ou quota d'essai (100/jour) dépassé
  def upc_product_title(ean)
    response = HTTP.timeout(10).get("https://api.upcitemdb.com/prod/trial/lookup", params: { upc: ean })
    unless response.status.success?
      Rails.logger.warn("[upcitemdb] #{response.status} pour #{ean}")
      return nil
    end
    JSON.parse(response.body.to_s).dig("items", 0, "title")
  end

  # Liste de jeux IGDB ([] si aucun résultat), nil si IGDB est indisponible
  def igdb_search(name, limit:)
    token = IgdbService.access_token
    return nil unless token

    response = HTTParty.post(
      "https://api.igdb.com/v4/games",
      headers: {
        "Client-ID" => Rails.application.credentials.dig(:igdb, :client_id),
        "Authorization" => "Bearer #{token}"
      },
      # Les guillemets fermeraient la chaîne de la requête IGDB : on les retire
      body: "fields name,cover.url,platforms.name,summary,genres.name,first_release_date; search \"#{name.delete('"\\')}\"; limit #{limit};",
      timeout: 10
    )
    # Token expiré ou révoqué : on l'oublie pour qu'un nouveau soit demandé au prochain appel
    Rails.cache.delete(IgdbService::CACHE_KEY) if response.code == 401
    return nil unless response.code == 200

    response.parsed_response
  end

  def igdb_game_json(game, summary:)
    cover_url = game.dig("cover", "url") ? "https:#{game['cover']['url'].gsub('t_thumb', 't_cover_big')}" : nil
    release_date = game["first_release_date"] ? Time.at(game["first_release_date"]).to_date : nil
    platforms = game["platforms"]&.map { |p| p["name"] }&.join(", ")
    genres = game["genres"]&.map { |g| g["name"] }&.join(", ")

    {
      id: game["id"],
      name: game["name"],
      cover_url: cover_url,
      platforms: platforms,
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

  def clean_game_title(title)
    platforms = [
      "Nintendo Switch", "PlayStation 5", "PS5", "PlayStation 4", "PS4",
      "Xbox Series X", "Xbox One", "PC", "Steam", "Nintendo 3DS", "Wii U"
    ]
    clean = title
    platforms.each do |platform|
      clean = clean.gsub(/\s*-\s*#{platform}/i, "")
      clean = clean.gsub(/\s*\(#{platform}\)/i, "")
      clean = clean.gsub(/\s*\[#{platform}\]/i, "")
    end
    clean.strip
  end
end
