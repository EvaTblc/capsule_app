class Api::SearchController < ApplicationController
  def game
    query = params[:query]
    api_key = Rails.application.credentials.dig(:rawg, :api_key)

    url = "https://api.rawg.io/api/games?key=#{api_key}&search=#{CGI.escape(query)}&page_size=5"
    response = Net::HTTP.get(URI(url))
    data = JSON.parse(response)

    results = data["results"]&.map do |game|
      {
        id: game["id"],
        title: game["name"],
        platform: game["platforms"]&.map { |p| p["platform"]["name"] }&.join(", "),
        genre: game["genres"]&.map { |g| g["name"] }&.join(", "),
        release_date: game["released"]
      }
    end

    render json: results
  end

  def game_detail
    api_key = Rails.application.credentials.dig(:rawg, :api_key)
    url = "https://api.rawg.io/api/games/#{params[:id]}?key=#{api_key}"
    response = Net::HTTP.get(URI(url))
    data = JSON.parse(response)

    render json: {
      description: ActionView::Base.full_sanitizer.sanitize(data["description"] || ""),
      developer: data["developers"]&.first&.dig("name")
    }
  end

  def game_barcode
    ean = params[:ean].to_s.strip
    return render json: { error: "Barcode manquant" }, status: :unprocessable_entity if ean.blank?

    token = IgdbService.access_token
    return render json: { error: "Token IGDB indisponible" }, status: :service_unavailable unless token

    # Étape 1 : UPCitemdb pour récupérer le nom
    upc_response = HTTP.get(
      "https://api.upcitemdb.com/prod/trial/lookup",
      params: { upc: ean }
    )
    upc_data = JSON.parse(upc_response.body.to_s)
    product = upc_data.dig('items', 0)

    return render json: { error: "Jeu non trouvé" }, status: :not_found unless product

    game_name = clean_game_title(product['title'])
    Rails.logger.info("[game_barcode] UPCitemdb: #{product['title']} → #{game_name}")

    # Étape 2 : IGDB par nom
    igdb_response = HTTParty.post(
      "https://api.igdb.com/v4/games",
      headers: {
        'Client-ID' => Rails.application.credentials.igdb[:client_id],
        'Authorization' => "Bearer #{token}"
      },
      body: "fields name,cover.url,platforms.name,summary,genres.name,first_release_date; search \"#{game_name}\"; limit 1;"
    )

    return render json: { error: "Jeu non trouvé sur IGDB" }, status: :not_found unless igdb_response.code == 200 && igdb_response.parsed_response.any?

    game = igdb_response.parsed_response.first
    cover_url = game.dig('cover', 'url') ? "https:#{game['cover']['url'].gsub('t_thumb', 't_cover_big')}" : nil
    release_date = game['first_release_date'] ? Time.at(game['first_release_date']).to_date : nil
    summary = TranslationService.translate_batch([game['summary'].to_s]).first

    render json: {
      id: game['id'],
      name: game['name'],
      cover_url: cover_url,
      platforms: game['platforms']&.map { |p| p['name'] }&.join(', '),
      release_date: game['first_release_date'] ? Time.at(game['first_release_date']).year : nil,
      summary: summary,
      genres: game['genres']&.map { |g| g['name'] }&.join(', '),
      metadata: {
        platforms: game['platforms']&.map { |p| p['name'] }&.join(', '),
        summary: summary,
        cover_url: cover_url,
        genres: game['genres']&.map { |g| g['name'] }&.join(', '),
        release_date: release_date&.to_s
      }
    }
  rescue => e
    Rails.logger.error("[game_barcode] Erreur: #{e.message}")
    render json: { error: e.message }, status: :internal_server_error
  end




  def search_game
    query = params[:query].to_s.strip
    return render json: { error: "Query vide" }, status: :unprocessable_entity if query.blank?

    token = IgdbService.access_token
    return render json: { error: "Token IGDB indisponible" }, status: :service_unavailable unless token

    response = HTTParty.post(
      "https://api.igdb.com/v4/games",
      headers: {
        'Client-ID' => Rails.application.credentials.igdb[:client_id],
        'Authorization' => "Bearer #{token}"
      },
      body: "fields name,cover.url,platforms.name,summary,genres.name,first_release_date; search \"#{query}\"; limit 10;"
    )

    return render json: { games: [] } unless response.code == 200 && response.parsed_response.any?

    games = response.parsed_response

    # Traduire tous les summaries en un seul appel
    summaries = games.map { |g| g['summary'].to_s }
    translated_summaries = TranslationService.translate_batch(summaries)

    result = games.each_with_index.map do |game, i|
      cover_url = game.dig('cover', 'url') ? "https:#{game['cover']['url'].gsub('t_thumb', 't_cover_big')}" : nil
      release_date = game['first_release_date'] ? Time.at(game['first_release_date']).to_date : nil
      summary = translated_summaries[i].presence || game['summary']

      {
        id: game['id'],
        name: game['name'],
        cover_url: cover_url,
        platforms: game['platforms']&.map { |p| p['name'] }&.join(', '),
        release_date: game['first_release_date'] ? Time.at(game['first_release_date']).year : nil,
        summary: summary,
        genres: game['genres']&.map { |g| g['name'] }&.join(', '),
        metadata: {
          platforms: game['platforms']&.map { |p| p['name'] }&.join(', '),
          summary: summary,
          cover_url: cover_url,
          genres: game['genres']&.map { |g| g['name'] }&.join(', '),
          release_date: release_date&.to_s
        }
      }
    end

    render json: { games: result }
  rescue => e
    Rails.logger.error("[search_game] Erreur: #{e.message}")
    render json: { error: e.message }, status: :internal_server_error
  end

  def book
    query = params[:query]
    api_key = Rails.application.credentials.dig(:google, :books_api_key)

    url = "https://www.googleapis.com/books/v1/volumes?q=#{CGI.escape(query)}&key=#{api_key}&maxResults=5&langRestrict=fr"
    response = Net::HTTP.get(URI(url))
    data = JSON.parse(response)

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
    query = params[:query]
    api_key = Rails.application.credentials.dig(:tmdb, :api_key)

    url = "https://api.themoviedb.org/3/search/movie?api_key=#{api_key}&query=#{CGI.escape(query)}&language=fr-FR"
    response = Net::HTTP.get(URI(url))
    data = JSON.parse(response)

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
    api_key = Rails.application.credentials.dig(:tmdb, :api_key)

    # Détails du film
    url = "https://api.themoviedb.org/3/movie/#{params[:id]}?api_key=#{api_key}&language=fr-FR"
    response = Net::HTTP.get(URI(url))
    data = JSON.parse(response)

    # Crédits pour le réalisateur
    credits_url = "https://api.themoviedb.org/3/movie/#{params[:id]}/credits?api_key=#{api_key}"
    credits_response = Net::HTTP.get(URI(credits_url))
    credits_data = JSON.parse(credits_response)

    director = credits_data["crew"]&.find { |p| p["job"] == "Director" }&.dig("name")

    render json: {
      director: director,
      studio: data["production_companies"]&.map { |c| c["name"] }&.join(", ")
    }
  end

  def music
    query = params[:query]
    token = Rails.application.credentials.dig(:discogs, :token)

    url = "https://api.discogs.com/database/search?q=#{CGI.escape(query)}&type=release&per_page=5&token=#{token}"

    uri = URI(url)
    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "CapsuleApp/1.0"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
    data = JSON.parse(response.body)

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
    token = Rails.application.credentials.dig(:discogs, :token)
    url = "https://api.discogs.com/releases/#{params[:id]}?token=#{token}"

    uri = URI(url)
    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "CapsuleApp/1.0"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
    data = JSON.parse(response.body)

    render json: {
      artist: data["artists"]&.map { |a| a["name"] }&.join(", "),
      description: data["notes"]
    }
  end

  private

  def clean_game_title(title)
    platforms = [
      "Nintendo Switch", "PlayStation 5", "PS5", "PlayStation 4", "PS4",
      "Xbox Series X", "Xbox One", "PC", "Steam", "Nintendo 3DS", "Wii U"
    ]
    clean = title
    platforms.each do |platform|
      clean = clean.gsub(/\s*-\s*#{platform}/i, '')
      clean = clean.gsub(/\s*\(#{platform}\)/i, '')
      clean = clean.gsub(/\s*\[#{platform}\]/i, '')
    end
    clean.strip
  end

end
