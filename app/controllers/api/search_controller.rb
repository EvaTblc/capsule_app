class Api::SearchController < ApplicationController
  class ExternalApiError < StandardError; end

  before_action :authenticate_user!
  before_action :require_numeric_id, only: [ :movie_detail, :music_detail ]
  # Scans : UPCitemdb (et Claude pour les jeux). Le scan de livre passe par la recherche Google Books, gratuite
  before_action :require_paid_features, only: [ :game_barcode, :movie_barcode ]
  rate_limit to: 20, within: 1.minute, only: [ :game_barcode, :search_game ]

  # Filets de sécurité communs à toutes les actions : le détail part dans les logs,
  # le navigateur ne reçoit qu'un message générique.
  # Rails prend le dernier rescue_from qui correspond : StandardError d'abord, sinon il attraperait aussi les API
  rescue_from StandardError, with: :render_internal_error
  rescue_from ExternalApiError, HTTP::Error, JSON::ParserError, with: :render_external_error

  def game_barcode
    ean = params[:ean].to_s.strip
    return render json: { error: "Barcode manquant" }, status: :unprocessable_entity if ean.blank?

    # Étape 1 : la boîte (déjà connue, sinon BnF → UPCitemdb → EAN-DB), étape 2 : les noms du jeu
    box = BarcodeService.lookup(ean, kind: :game)
    return render json: { error: "Jeu non trouvé", fallback: true }, status: :not_found unless box
    return render_other_kind(box, :game) unless box.game?

    names = scanned_names(box)
    Rails.logger.info("[game_barcode] #{box.source} : #{box.raw_title} → #{names.inspect}")

    # Étape 3 : IGDB par nom (titre principal, puis titre français), en écartant les jeux dont le titre ne correspond pas
    game = nil
    names.each do |name|
      games = IgdbService.search(name, limit: 3)
      return render json: { error: "IGDB indisponible" }, status: :service_unavailable if games.nil?

      game = games.find { |candidate| matching_title?(name, igdb_titles(candidate)) }
      break if game
    end
    return render json: { error: "Jeu non trouvé", fallback: true }, status: :not_found unless game

    summary = begin
      TranslationService.translate_batch([ game["summary"].to_s ]).first
    rescue TranslationService::Error => e
      Rails.logger.warn("[game_barcode] Traduction impossible, résumé laissé en anglais : #{e.message}")
      game["summary"]
    end

    # La boîte dit sur quelle plateforme est le jeu possédé, et son édition ; le code-barres est gardé avec l'item
    json = igdb_game_json(game, summary: summary)
    render json: json.merge(platform: box.platform || json[:platform], edition: box.edition, barcode: box.barcode)
  end

  def movie_barcode
    ean = params[:ean].to_s.strip
    return render json: { error: "Barcode manquant" }, status: :unprocessable_entity if ean.blank?

    # Étape 1 : la boîte (déjà connue, sinon BnF → UPCitemdb → EAN-DB), étape 2 : les titres du film
    # (TMDB ne sait pas chercher par EAN : sans titre, on passe en recherche manuelle)
    box = BarcodeService.lookup(ean, kind: :movie)
    return render json: { error: "Film non trouvé", fallback: true }, status: :not_found unless box
    return render_other_kind(box, :movie) unless box.movie?

    names = scanned_names(box)
    Rails.logger.info("[movie_barcode] #{box.source} : #{box.raw_title} → #{names.inspect}")

    # Étape 3 : TMDB par titre (original, puis français), en écartant les films dont le titre ne correspond pas
    movie = nil
    names.each do |name|
      results = tmdb_get("search/movie", query: name, language: "fr-FR")["results"] || []
      movie = results.first(3).find { |candidate| matching_title?(name, [ candidate["title"], candidate["original_title"] ]) }
      break if movie
    end
    return render json: { error: "Film non trouvé", fallback: true }, status: :not_found unless movie

    # Étape 4 : la fiche vient du catalogue (Wikidata, Wikipédia) et non de TMDB, qui interdit de conserver ses données
    product = ProductCatalog.movie(movie["id"])
    return render_movie_unavailable unless product

    # La boîte dit le format et l'édition du film possédé ; le code-barres est gardé avec l'item
    render json: catalog_movie_json(product).merge(format: box.format, edition: box.edition, barcode: box.barcode)
  end

  def search_game
    query = params[:query].to_s.strip
    return render json: { error: "Query vide" }, status: :unprocessable_entity if query.blank?

    games = IgdbService.search(query, limit: 10)
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

    # Affichage seulement (titre, auteur) : la fiche du livre choisi vient ensuite de la BnF par son ISBN (book_detail).
    # Google interdit d'en garder des copies : rien de Google Books n'est enregistré
    results = data["items"]&.map do |item|
      info = item["volumeInfo"]
      { id: item["id"], title: info["title"], author: info["authors"]&.join(", "),
        isbn: info["industryIdentifiers"]&.find { |i| i["type"] == "ISBN_13" }&.dig("identifier") }
    end
    render json: results || []
  end

  # Fiche d'un livre par son ISBN (choisi dans la recherche ou scanné) : notice de la BnF (Licence Ouverte),
  # œuvre et résumé de Wikidata / Wikipédia. Gratuit pour tous : ni UPCitemdb, ni EAN-DB (payant), ni Claude
  def book_detail
    box = BarcodeService.lookup(params[:isbn], kind: :book, bnf_only: true)
    unless box
      return render json: { error: "Livre introuvable à la BnF : complète la fiche à la main.", fallback: true }, status: :not_found
    end
    return render_other_kind(box, :book) unless box.book?

    author = box.details.dig("creators", "070").to_a.first(3).join(", ").presence
    work_id = WikimediaService.book_work_id(title: box.details["title"], author: author)
    product = ProductCatalog.book(work_id) if work_id

    render json: {
      wikidata_id: product&.wikidata_id,
      title: box.details["title"] || box.raw_title,
      author: author,
      publisher: box.publisher,
      pages: box.details["support"].to_s[/(\d+)\s*p\b/, 1]&.to_i, # « 1 vol. (580 p.) », « 1 volume 191 p »
      genre: product&.details&.dig("genres")&.first,
      isbn: box.barcode,
      description: product&.description,
      barcode: box.barcode
    }
  end

  def movie
    query = params[:query].to_s.strip
    return render json: [] if query.blank?

    data = tmdb_get("search/movie", query: query, language: "fr-FR")

    # Affichage seulement (titre, année) : la fiche du film choisi vient ensuite du catalogue (movie_detail)
    results = data["results"]&.first(5)&.map do |movie|
      { id: movie["id"], title: movie["title"], year: movie["release_date"]&.split("-")&.first }
    end

    render json: results || []
  end

  # Fiche du film choisi dans la recherche (identifiant TMDB), lue au catalogue : Wikidata et Wikipédia, jamais TMDB
  def movie_detail
    product = ProductCatalog.movie(params[:id])
    return render_movie_unavailable unless product

    render json: catalog_movie_json(product)
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

  # Une API externe a échoué (panne, quota, timeout, réponse illisible) : attendu, une ligne de log suffit
  def render_external_error(error)
    Rails.logger.warn("[api/search##{action_name}] #{error.class}: #{error.message}")
    render json: { error: "Recherche indisponible" }, status: :bad_gateway
  end

  # Bug chez nous : en dev et en test, l'erreur remonte pour être vue tout de suite ;
  # en prod, le formulaire reçoit quand même du JSON, et les logs l'endroit du plantage
  def render_internal_error(error)
    raise error if Rails.env.local?

    trace = Rails.backtrace_cleaner.clean(error.backtrace.to_a).first(5).join(" | ")
    Rails.logger.error("[api/search##{action_name}] #{error.class}: #{error.message} | #{trace}")
    render json: { error: "Recherche indisponible" }, status: :internal_server_error
  end

  # Noms à chercher pour une boîte (extraits une fois par Claude, puis gardés avec elle).
  # S'il ne répond pas : nom nettoyé par règles (moins fiable, mais mieux que rien), non gardé
  def scanned_names(box)
    BarcodeService.names_for(box)
  rescue BarcodeService::Error => e
    Rails.logger.warn("[#{box.kind}_barcode] Claude indisponible, nettoyage par règles : #{e.message}")
    [ box.game? ? clean_game_title(box.raw_title) : clean_movie_title(box.raw_title) ]
  end

  # Fiche de film pour pré-remplir le formulaire ; tmdb_id repart avec le formulaire pour relier l'item à l'œuvre
  def catalog_movie_json(product)
    {
      tmdb_id: product.tmdb_id,
      title: product.title,
      year: product.release_year,
      description: product.description,
      director: product.creator,
      studio: product.details["studios"].to_a.first(3).join(", ").presence
    }
  end

  # Film inconnu de Wikidata : on ne pré-remplit pas avec les données de TMDB (non conservables)
  def render_movie_unavailable
    render json: { error: "Fiche indisponible pour ce film : complète-la à la main.", fallback: true, unavailable: true },
           status: :not_found
  end

  KIND_LABELS = { "game" => "un jeu vidéo", "movie" => "un film", "book" => "un livre" }.freeze

  # Code-barres d'un autre type que le formulaire (livre scanné depuis le formulaire jeu...) :
  # on le dit, au lieu de pré-remplir avec n'importe quoi
  def render_other_kind(box, expected)
    render json: { error: "Ce code-barres correspond à #{KIND_LABELS[box.kind]}, pas à #{KIND_LABELS[expected.to_s]}.",
                   fallback: true, other_kind: box.kind }, status: :not_found
  end

  # Mots qui ne distinguent pas un titre d'un autre
  TITLE_FILLER_WORDS = %w[the a an of and version edition le la les l de du des et].freeze

  # Garde-fou des scans : tous les mots significatifs du nom cherché doivent figurer dans l'un des titres trouvés.
  # « Pokemon Diamond » refuse « Pokémon White Version 2 » : mieux vaut « introuvable » qu'un mauvais jeu ajouté en silence
  def matching_title?(wanted, titles)
    wanted_words = significant_words(wanted)
    titles.compact.any? { |title| wanted_words.subset?(significant_words(title)) }
  end

  def significant_words(title)
    IgdbService.normalize_title(title).split.to_set - TITLE_FILLER_WORDS
  end

  # Titre d'origine et titres alternatifs (français, européen...) d'un jeu IGDB
  def igdb_titles(game)
    [ game["name"], *game["alternative_names"]&.map { |alt| alt["name"] } ]
  end

  def igdb_game_json(game, summary:)
    cover_url = game.dig("cover", "url") ? "https:#{game['cover']['url'].gsub('t_thumb', 't_cover_big')}" : nil
    release_date = IgdbService.release_date(game)
    platforms = game["platforms"]&.map { |p| p["name"] }&.join(", ")
    genres = game["genres"]&.map { |g| g["name"] }&.join(", ")
    french_name = IgdbService.french_title(game)
    developers = IgdbService.developers(game)
    # Plateforme de l'appli, seulement si le jeu n'existe que sur une seule : sinon c'est à l'utilisateur de choisir
    app_platforms = game["platforms"]&.filter_map { |p| VideoGameDetail::IGDB_PLATFORMS[p["name"]] }&.uniq || []

    {
      id: game["id"],
      # Titre français officiel quand IGDB le connaît, sinon titre d'origine
      name: french_name || game["name"],
      # Titre d'origine, affiché en petit pour reconnaître le jeu (nil s'il est identique)
      original_name: (game["name"] if french_name && french_name != game["name"]),
      cover_url: cover_url,
      platforms: platforms,
      platform: (app_platforms.first if app_platforms.one?),
      developer: developers.presence&.join(", "),
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

  # « Switch » seul n'y figure pas : il fait partie de titres (« Switch Sports »)
  GAME_PLATFORMS = [
    "Nintendo Switch 2", "Nintendo Switch", "PlayStation 5", "PlayStation 4", "PS5", "PS4",
    "Xbox Series X", "Xbox Series S", "Xbox One", "PC", "Steam", "Nintendo 3DS", "Wii U"
  ].freeze

  # Repli quand Claude ne répond pas. Titre UPCitemdb → nom de jeu cherchable sur IGDB, ex. :
  # « Mario Kart 8 Deluxe - Nintendo Switch Video Game - European Version (International Version) » → « Mario Kart 8 Deluxe »
  def clean_game_title(title)
    clean = title.gsub(/\(.*?\)|\[.*?\]/, " ")           # (International Version), [Import]...
    clean = clean.split(/\s+[-–:|]\s+/).first.to_s         # ce qui suit un séparateur espacé : console, édition, région
    GAME_PLATFORMS.each do |platform|
      # Jamais en début de titre : « Nintendo Switch Sports » doit rester intact
      clean = clean.gsub(/(?<=\S)\s+#{Regexp.escape(platform)}(?![\w-])/i, " ")
    end
    clean = clean.gsub(/\b(video game|import region free)\b/i, " ")
    clean.gsub(/(\w) s (?=\w)/, "\\1's ").squeeze(" ").strip # « Luigi s Mansion » → « Luigi's Mansion »
  end
end
