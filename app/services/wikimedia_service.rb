# Films depuis Wikidata (licence CC0 : stockage et réutilisation libres) et résumés depuis Wikipédia en français
# (CC BY-SA : à citer, avec un lien vers l'article). Remplace TMDB pour tout ce qui est conservé :
# TMDB interdit de garder ses données plus de 6 mois, on ne s'en sert que pour trouver le film.
class WikimediaService
  WIKIDATA_API = "https://www.wikidata.org/w/api.php".freeze
  WIKIPEDIA_SUMMARY = "https://fr.wikipedia.org/api/rest_v1/page/summary/".freeze
  # Wikimedia demande un User-Agent qui identifie l'application
  HEADERS = { "User-Agent" => "CapsuleApp/1.0 (https://www.capsule.click)" }.freeze
  FRANCE = "Q142"
  # Résultats à écarter pour un livre : une édition précise, ou une série entière (sinon chaque tome de One Piece
  # serait relié à la série). Édition, série littéraire, série de BD, série de mangas, cycle de romans, série d'œuvres
  NOT_A_BOOK_WORK = %w[Q3331189 Q277759 Q14406742 Q21198342 Q1667921 Q7725310].freeze

  # Film par son identifiant TMDB (propriété P4947 de Wikidata), nil s'il est inconnu ou si Wikidata ne répond pas
  def self.movie(tmdb_id)
    params = { action: "query", list: "search", srsearch: "haswbstatement:P4947=#{Integer(tmdb_id)}", srlimit: 1, format: "json" }
    # La recherche de Wikidata répond parfois par une erreur passagère (sans « query ») : un second essai suffit
    search = get_json(WIKIDATA_API, **params)
    search = get_json(WIKIDATA_API, **params) unless search&.key?("query")
    qid = search&.dig("query", "search", 0, "title")
    return nil unless qid

    entity = entities([ qid ], props: "labels|claims|sitelinks")&.dig(qid)
    return nil unless entity

    claims = entity["claims"]
    names = labels(item_ids(claims, "P57") + item_ids(claims, "P272"))
    {
      wikidata_id: qid,
      title: label(entity),
      original_title: claims.dig("P1476", 0, "mainsnak", "datavalue", "value", "text"),
      release_year: release_year(claims),
      directors: item_ids(claims, "P57").filter_map { |id| names[id] },
      studios: item_ids(claims, "P272").filter_map { |id| names[id] },
      wikipedia_title: entity.dig("sitelinks", "frwiki", "title")
    }
  end

  # Identifiant Wikidata de l'œuvre d'un livre, trouvée par son titre et son auteur (tels que lus à la BnF) ;
  # nil si aucune œuvre ne correspond vraiment (même titre, et un auteur du même nom)
  def self.book_work_id(title:, author:)
    return nil if title.blank? || author.blank?

    params = { action: "query", list: "search", srsearch: "\"#{title.delete('"')}\" haswbstatement:P50", srlimit: 5, format: "json" }
    search = get_json(WIKIDATA_API, **params)
    search = get_json(WIKIDATA_API, **params) unless search&.key?("query")
    ids = search&.dig("query", "search").to_a.map { |result| result["title"] }
    return nil if ids.empty?

    candidates = entities(ids, props: "labels|claims") || {}
    author_names = labels(candidates.values.flat_map { |entity| item_ids(entity["claims"], "P50") })
    wanted_title = normalize(title)
    wanted_author = normalize(author).split.last

    ids.find do |id|
      entity = candidates[id]
      next false unless entity
      next false if (item_ids(entity["claims"], "P31") & NOT_A_BOOK_WORK).any?

      normalize(label(entity)) == wanted_title &&
        item_ids(entity["claims"], "P50").any? { |author_id| normalize(author_names[author_id]).split.include?(wanted_author) }
    end
  end

  # Œuvre littéraire par son identifiant Wikidata (il vient du navigateur : on vérifie que c'est bien une œuvre
  # avec un auteur, et pas une édition ou une série) ; nil sinon
  def self.book(wikidata_id)
    return nil unless wikidata_id.to_s.match?(/\AQ\d+\z/)

    entity = entities([ wikidata_id ], props: "labels|claims|sitelinks")&.dig(wikidata_id)
    return nil unless entity

    claims = entity["claims"]
    return nil if item_ids(claims, "P50").empty? || (item_ids(claims, "P31") & NOT_A_BOOK_WORK).any?

    names = labels(item_ids(claims, "P50") + item_ids(claims, "P136"))
    {
      wikidata_id: wikidata_id,
      title: label(entity),
      original_title: claims.dig("P1476", 0, "mainsnak", "datavalue", "value", "text"),
      release_year: release_year(claims),
      authors: item_ids(claims, "P50").filter_map { |id| names[id] },
      genres: item_ids(claims, "P136").filter_map { |id| names[id] },
      wikipedia_title: entity.dig("sitelinks", "frwiki", "title")
    }
  end

  # Introduction de l'article Wikipédia en français et son adresse ; nil si l'article n'existe pas
  def self.summary(title)
    return nil if title.blank?

    data = get_json(WIKIPEDIA_SUMMARY + ERB::Util.url_encode(title.tr(" ", "_")))
    return nil unless data && data["type"] == "standard" # pas une page d'homonymie

    { text: data["extract"], url: data.dig("content_urls", "desktop", "page") }
  end

  def self.entities(ids, props:)
    get_json(WIKIDATA_API, action: "wbgetentities", ids: ids.join("|"), props: props, languages: "fr|en",
                           sitefilter: "frwiki", format: "json")&.dig("entities")
  end

  # Identifiants des éléments cités par une propriété (réalisateurs P57, sociétés de production P272)
  def self.item_ids(claims, property)
    claims[property].to_a.filter_map { |claim| claim.dig("mainsnak", "datavalue", "value", "id") }
  end

  # Libellés français (anglais à défaut) de plusieurs éléments, en un seul appel
  def self.labels(ids)
    return {} if ids.empty?

    (entities(ids.uniq.first(50), props: "labels") || {}).transform_values { |entity| label(entity) }
  end

  def self.label(entity)
    entity.dig("labels", "fr", "value") || entity.dig("labels", "en", "value")
  end

  # Année de sortie en France si Wikidata la connaît (qualificatif P291 = France), sinon la plus ancienne
  def self.release_year(claims)
    dates = claims["P577"].to_a.filter_map do |claim|
      time = claim.dig("mainsnak", "datavalue", "value", "time")
      next unless time

      places = claim.dig("qualifiers", "P291").to_a.filter_map { |q| q.dig("datavalue", "value", "id") }
      { year: time[1, 4].to_i, france: places.include?(FRANCE) }
    end
    (dates.find { |date| date[:france] } || dates.min_by { |date| date[:year] })&.dig(:year)
  end

  # Pour comparer des titres et des noms : sans accents, majuscules ni ponctuation
  def self.normalize(text)
    I18n.transliterate(text.to_s).downcase.gsub(/[^a-z0-9]+/, " ").strip
  end

  def self.get_json(url, **params)
    response = HTTP.timeout(10).headers(HEADERS).get(url, params: params)
    return log_miss(url, response.status) unless response.status.success?

    JSON.parse(response.body.to_s)
  rescue HTTP::Error, JSON::ParserError => e
    log_miss(url, e.class)
  end

  def self.log_miss(url, reason)
    Rails.logger.warn("[wikimedia] #{reason} pour #{url}")
    nil
  end
  private_class_method :entities, :item_ids, :labels, :label, :release_year, :normalize, :get_json, :log_miss
end
