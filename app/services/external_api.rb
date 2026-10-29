# Appels des API de recherche externes (TMDB, Google Books, Discogs) : GET JSON avec timeout.
# Lève ExternalApi::Error si l'API répond en erreur (clé invalide, quota, 500...)
module ExternalApi
  class Error < StandardError; end

  def self.get_json(url, params: {}, headers: {})
    response = HTTP.timeout(10).headers(headers).get(url, params: params)
    raise Error, "#{URI(url).host} a répondu #{response.status}" unless response.status.success?

    JSON.parse(response.body.to_s)
  end

  # Affichage temporaire seulement : TMDB interdit de conserver ses données
  def self.tmdb(path, **params)
    get_json("https://api.themoviedb.org/3/#{path}",
             params: params.merge(api_key: Rails.application.credentials.dig(:tmdb, :api_key)))
  end

  # Affichage seulement : Google interdit d'en garder des copies
  def self.google_books(**params)
    get_json("https://www.googleapis.com/books/v1/volumes",
             params: params.merge(key: Rails.application.credentials.dig(:google, :books_api_key)))
  end

  def self.discogs(path, **params)
    get_json("https://api.discogs.com/#{path}",
             params: params.merge(token: Rails.application.credentials.dig(:discogs, :token)),
             headers: { "User-Agent" => "CapsuleApp/1.0" }) # Discogs refuse les requêtes sans User-Agent
  end
end
