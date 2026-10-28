# Reprise des items créés avant le catalogue : les relie à leur œuvre, et remplace les données de TMDB et
# de Google Books qu'ils contiennent encore (leurs conditions interdisent de les conserver) par celles du catalogue.
# Prudente : rien n'est relié en cas de doute, et un champ modifié par l'utilisateur n'est jamais remplacé
# (seuls les champs encore identiques à ce que renvoie la source aujourd'hui le sont).
# apply: false (par défaut) : tout est calculé puis annulé, pour lire le rapport sans rien écrire.
# Relançable sans risque : un item déjà relié est ignoré.
class CatalogBackfill
  Result = Struct.new(:item, :status, :product, :replaced, :note, keyword_init: true)

  TYPES = %w[VideoGameDetail MovieDetail BookDetail].freeze
  # Ne pas solliciter IGDB (4 requêtes par seconde au plus), TMDB, Wikidata et la BnF en rafale
  PAUSE = 1

  def initialize(apply: false, pause: PAUSE)
    @apply = apply
    @pause = pause
  end

  def run(items = Item.where(product_id: nil, item_detailable_type: TYPES).includes(:item_detailable))
    items.find_each.map do |item|
      result = process(item)
      sleep(@pause)
      result
    end
  end

  private

  # Chaque item dans sa propre transaction : en mode essai, tout (œuvres créées comprises) est annulé
  def process(item)
    result = nil
    Item.transaction do
      result = case item.item_detailable_type
      when "VideoGameDetail" then backfill_game(item)
      when "MovieDetail" then backfill_movie(item)
      when "BookDetail" then backfill_book(item)
      end
      raise ActiveRecord::Rollback unless @apply
    end
    result
  rescue StandardError => e
    Result.new(item: item, status: :error, note: "#{e.class}: #{e.message}")
  end

  # --- Jeux : un seul jeu IGDB portant exactement ce titre (ou départagé par la plateforme) ---

  def backfill_game(item)
    query = item.title.to_s.delete('"\\')
    fields = IgdbService::GAME_FIELDS.join(",")
    found = IgdbService.post("games", "fields #{fields}; search \"#{query}\"; limit 10;")
    # IGDB muet (limite de débit, panne) : ce n'est pas « aucun jeu », on le dit pour relancer plus tard
    return Result.new(item: item, status: :error, note: "IGDB n'a pas répondu") if found.nil?

    french = IgdbService.post("alternative_names", "fields #{IgdbService::GAME_FIELDS.map { |f| "game.#{f}" }.join(',')}; " \
                                                   "where name = \"#{query}\" & comment = \"French title\"; limit 5;")
    games = found + french.to_a.filter_map { |match| match["game"] }
    exact = games.uniq { |game| game["id"] }.select do |game|
      [ game["name"], IgdbService.french_title(game) ].compact.any? { |title| normalize(title) == normalize(item.title) }
    end
    if exact.size > 1 && item.item_detailable.platform.present?
      on_platform = exact.select { |game| game["platforms"].to_a.any? { |p| VideoGameDetail::IGDB_PLATFORMS[p["name"]] == item.item_detailable.platform } }
      # La plateforme ne départage que si elle garde au moins un jeu (sinon : ambigu, pas introuvable)
      exact = on_platform if on_platform.any?
    end
    return Result.new(item: item, status: exact.empty? ? :not_found : :ambiguous, note: "#{exact.size} jeux au même titre") unless exact.one?

    product = ProductCatalog.game(exact.first["id"])
    return Result.new(item: item, status: :not_found, note: "IGDB indisponible") unless product

    link(item, product, replaced: copy_missing_description(item, product))
  end

  # --- Films : TMDB pour trouver l'identifiant (titre exact, année à un an près), fiche de Wikidata ---

  def backfill_movie(item)
    detail = item.item_detailable
    results = tmdb_get("search/movie", query: item.title, language: "fr-FR")&.dig("results").to_a
    matches = results.select do |movie|
      [ movie["title"], movie["original_title"] ].any? { |title| normalize(title) == normalize(item.title) } &&
        (detail.year.blank? || (movie["release_date"].to_s[0, 4].to_i - detail.year).abs <= 1)
    end
    return Result.new(item: item, status: matches.empty? ? :not_found : :ambiguous, note: "#{matches.size} films TMDB") unless matches.one?

    tmdb_id = matches.first["id"]
    product = ProductCatalog.movie(tmdb_id)
    return Result.new(item: item, status: :not_found, note: "absent de Wikidata : données TMDB laissées en place") unless product

    # Ce que TMDB renvoie aujourd'hui : un champ encore identique vient de TMDB, il est remplacé par le catalogue
    tmdb = tmdb_get("movie/#{tmdb_id}", language: "fr-FR") || {}
    director = tmdb_get("movie/#{tmdb_id}/credits")&.dig("crew").to_a.find { |p| p["job"] == "Director" }&.dig("name")
    from_tmdb = { description: tmdb["overview"], director: director, year: tmdb["release_date"].to_s[0, 4].to_i.nonzero?,
                  studio: tmdb["production_companies"].to_a.pluck("name").join(", ").presence }
    from_catalog = { description: product.description, director: product.creator, year: product.release_year,
                     studio: product.details["studios"].to_a.first(3).join(", ").presence }
    replaced = replace_fields(detail, from_tmdb, from_catalog)
    link(item, product, replaced: replaced)
  end

  # --- Livres : par l'ISBN, notice de la BnF et œuvre de Wikidata ---

  def backfill_book(item)
    detail = item.item_detailable
    return Result.new(item: item, status: :not_found, note: "pas d'ISBN") if detail.isbn.blank?

    isbn = detail.isbn.delete("^0-9")
    box = BarcodeService.lookup(isbn, kind: :book, bnf_only: true)
    return Result.new(item: item, status: :not_found, note: "inconnu de la BnF") unless box&.book?

    author = box.details.dig("creators", "070").to_a.first(3).join(", ").presence
    work_id = WikimediaService.book_work_id(title: box.details["title"], author: author)
    product = ProductCatalog.book(work_id) if work_id

    google = google_book(isbn) || {}
    from_google = { description: google["description"], publisher: google["publisher"], pages: google["pageCount"],
                    genre: google["categories"].to_a.join(", ").presence }
    from_catalog = { description: product&.description, publisher: box.publisher,
                     pages: box.details["support"].to_s[/(\d+)\s*p\b/, 1]&.to_i, genre: product&.details&.dig("genres")&.first }
    replaced = replace_fields(detail, from_google, from_catalog)
    return Result.new(item: item, status: :not_found, replaced: replaced, note: "œuvre absente de Wikidata") unless product

    link(item, product, replaced: replaced)
  end

  # --- Outils communs ---

  def link(item, product, replaced:)
    item.update!(product: product)
    Result.new(item: item, status: :linked, product: product, replaced: replaced)
  end

  # Remplace chaque champ encore identique à la source interdite (TMDB, Google) par la valeur du catalogue,
  # ou le vide si le catalogue n'en a pas : la donnée de la source ne doit pas rester. Renvoie les champs remplacés
  def replace_fields(detail, from_source, from_catalog)
    changes = from_source.each_with_object({}) do |(field, source_value), result|
      current = detail.public_send(field)
      next if current.blank? || source_value.blank? || current.to_s.strip != source_value.to_s.strip
      # Même valeur au catalogue (année, réalisateur...) : rien à changer, la donnée est désormais celle du catalogue
      next if from_catalog[field].to_s.strip == current.to_s.strip

      result[field] = from_catalog[field]
    end
    detail.update!(changes) if changes.any?
    changes.keys
  end

  # Jeu sans description française : celle de l'œuvre si elle a déjà été traduite
  def copy_missing_description(item, product)
    detail = item.item_detailable
    return [] unless detail.description.blank? && product.description.present?

    detail.update!(description: product.description)
    [ :description ]
  end

  # Affichage temporaire seulement (rien n'est conservé de TMDB) ; nil si TMDB ne répond pas
  def tmdb_get(path, **params)
    response = HTTP.timeout(10).get("https://api.themoviedb.org/3/#{path}",
                                    params: params.merge(api_key: Rails.application.credentials.dig(:tmdb, :api_key)))
    response.status.success? ? JSON.parse(response.body.to_s) : nil
  rescue HTTP::Error, JSON::ParserError
    nil
  end

  # Ce que Google Books renvoie aujourd'hui pour cet ISBN (pour reconnaître ses données, pas pour les garder)
  def google_book(isbn)
    response = HTTP.timeout(10).get("https://www.googleapis.com/books/v1/volumes",
                                    params: { q: "isbn:#{isbn}", key: Rails.application.credentials.dig(:google, :books_api_key) })
    response.status.success? ? JSON.parse(response.body.to_s).dig("items", 0, "volumeInfo") : nil
  rescue HTTP::Error, JSON::ParserError
    nil
  end

  def normalize(text)
    I18n.transliterate(text.to_s).downcase.gsub(/[^a-z0-9]+/, " ").strip
  end
end
