# Films depuis Wikidata (licence CC0 : stockage et réutilisation libres) et résumés depuis Wikipédia en français
# (CC BY-SA : à citer, avec un lien vers l'article). Remplace TMDB pour tout ce qui est conservé :
# TMDB interdit de garder ses données plus de 6 mois, on ne s'en sert que pour trouver le film.
class WikimediaService
  WIKIDATA_API = "https://www.wikidata.org/w/api.php".freeze
  WIKIPEDIA_SUMMARY = "https://fr.wikipedia.org/api/rest_v1/page/summary/".freeze
  # Wikimedia demande un User-Agent qui identifie l'application
  HEADERS = { "User-Agent" => "CapsuleApp/1.0 (https://www.capsule.click)" }.freeze
  FRANCE = "Q142"

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
  private_class_method :entities, :item_ids, :labels, :label, :release_year, :get_json, :log_miss
end
