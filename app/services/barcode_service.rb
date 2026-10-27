# Code-barres d'un jeu ou d'un film → informations pour pré-remplir le formulaire, en deux étapes :
# 1. product_title : titre brut du produit, UPCitemdb d'abord, EAN-DB en secours
# 2. product_details : Claude extrait de ce titre brut, souvent une annonce de vendeur
#    (« Game: Pokemon Diamant Edition for Nintendo DS + LITE + DSi... ») qu'aucune règle ne sait nettoyer,
#    les noms à chercher sur IGDB / TMDB, et ce que la boîte dit du produit possédé : plateforme ou format, édition
class BarcodeService
  class Error < StandardError; end

  # Titre principal : celui qu'IGDB / TMDB cherchent le mieux. IGDB ne cherche pas dans les titres régionaux
  # (« Spectre's Call » ne trouve rien, « Last Specter » oui) : d'où le titre nord-américain pour les jeux.
  # support : plateforme d'un jeu ou format d'un film, limité aux valeurs de l'appli
  KINDS = {
    game: { label: "un jeu vidéo", title: "son titre principal tel que référencé sur IGDB (en général le titre nord-américain)",
            support: "platform", support_label: "sa plateforme", choices: VideoGameDetail::PLATFORMS - [ "Autres" ] },
    movie: { label: "un film (DVD, Blu-ray...)", title: "son titre original",
             support: "format", support_label: "son format", choices: MovieDetail::FORMATS }
  }.freeze

  # Titre brut du produit, nil si aucune des deux bases ne connaît le code.
  # Le code est inséré dans l'URL d'EAN-DB : on n'accepte que des chiffres (EAN-8 à GTIN-14)
  def self.product_title(ean)
    return nil unless ean.to_s.match?(/\A\d{8,14}\z/)

    upcitemdb_title(ean) || ean_db_title(ean)
  end

  # Extrait du titre brut :
  # - names : noms à chercher, titre principal puis titre français (sans doublon) ; [] si le produit
  #   n'est pas du type attendu (console, accessoire, coffret...)
  # - platform (jeu) ou format (film) : seulement une valeur de la liste de l'appli, sinon nil
  # - edition : nil pour l'édition standard
  # Lève BarcodeService::Error si Claude ne répond pas : à l'appelant de prévoir un repli.
  def self.product_details(raw_title, kind:)
    config = KINDS.fetch(kind)
    support = config[:support]
    result = AnthropicClient.json(
      "Voici le titre d'un produit trouvé grâce à son code-barres : #{raw_title.to_json}\n" \
      "S'il s'agit d'#{config[:label]}, réponds avec :\n" \
      "- title : #{config[:title]}\n" \
      "- french_title : son titre officiel en France\n" \
      "- #{support} : #{config[:support_label]}, parmi #{config[:choices].to_json}, ou null si le titre ne l'indique pas\n" \
      "- edition : son édition si ce n'est pas l'édition standard (ex : « Collector », « Steelbook »), sinon null\n" \
      "Les titres sans plateforme, format, édition ni mention commerciale. Si ce n'est pas #{config[:label]}, mets tout à null.\n" \
      "Réponds UNIQUEMENT avec un JSON valide, sans markdown : " \
      "{\"title\": \"...\", \"french_title\": \"...\", \"#{support}\": \"...\", \"edition\": null}"
    )
    raise Error, "Réponse inattendue : #{result.to_json.truncate(200)}" unless result.is_a?(Hash)

    {
      names: result.values_at("title", "french_title").compact_blank.uniq,
      support.to_sym => (result[support] if config[:choices].include?(result[support])),
      edition: result["edition"].presence
    }
  rescue AnthropicClient::Error => e
    raise Error, e.message
  end

  # Essai gratuit, sans clé : 100 requêtes par jour et par IP (IP Heroku partagées). Base surtout américaine
  def self.upcitemdb_title(ean)
    response = HTTP.timeout(10).get("https://api.upcitemdb.com/prod/trial/lookup", params: { upc: ean })
    return log_miss("upcitemdb", ean, response.status) unless response.status.success?

    JSON.parse(response.body.to_s).dig("items", 0, "title").presence
  rescue HTTP::Error, JSON::ParserError => e
    log_miss("upcitemdb", ean, e.class)
  end

  # Base européenne, payante (crédit d'appels prépayé), titres par langue : on préfère le français
  def self.ean_db_title(ean)
    token = Rails.application.credentials.dig(:ean_db, :api_key)
    return nil if token.blank?

    response = HTTP.timeout(10).auth("Bearer #{token}").headers(accept: "application/json")
                   .get("https://ean-db.com/api/v2/product/#{ean}")
    return log_miss("ean-db", ean, response.status) unless response.status.success?

    titles = JSON.parse(response.body.to_s).dig("product", "titles") || {}
    (titles["fr"] || titles["en"] || titles.values.first).presence
  rescue HTTP::Error, JSON::ParserError => e
    log_miss("ean-db", ean, e.class)
  end

  def self.log_miss(source, ean, reason)
    Rails.logger.warn("[#{source}] #{reason} pour #{ean}")
    nil
  end
  private_class_method :upcitemdb_title, :ean_db_title, :log_miss
end
