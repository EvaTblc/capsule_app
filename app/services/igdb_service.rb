class IgdbService
  CACHE_KEY = "igdb_access_token"

  def self.access_token
    token = Rails.cache.read(CACHE_KEY)
    if token.nil?
      token = fetch_new_token
      Rails.cache.write(CACHE_KEY, token, expires_in: 59.days)
    end
    token
  end

  private

  def self.fetch_new_token
    response = HTTP.post(
      "https://id.twitch.tv/oauth2/token",
      params: {
        client_id: Rails.application.credentials.igdb[:client_id],
        client_secret: Rails.application.credentials.igdb[:client_secret],
        grant_type: 'client_credentials'
      }
    )
    JSON.parse(response.body.to_s)['access_token']
  rescue => e
    Rails.logger.error("IGDB token fetch failed: #{e.message}")
    nil
  end
end
