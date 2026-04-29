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
end
