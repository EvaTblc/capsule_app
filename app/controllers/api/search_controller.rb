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
end
