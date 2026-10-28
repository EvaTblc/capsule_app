# Œuvres du catalogue partagé (Product), créées ou rafraîchies côté serveur à partir des sources officielles.
# On ne reçoit du navigateur qu'un identifiant : les données viennent toujours de la source, jamais du formulaire.
class ProductCatalog
  # Jeu par son identifiant IGDB : déjà au catalogue et récent, sinon (re)lu chez IGDB.
  # nil si l'identifiant est invalide, ou si le jeu n'est pas au catalogue et qu'IGDB ne répond pas
  def self.game(igdb_id)
    igdb_id = positive_id(igdb_id)
    return nil unless igdb_id

    product = Product.find_by(igdb_id: igdb_id)
    return product if product && !product.stale?

    game = IgdbService.game(igdb_id)
    return product unless game # IGDB indisponible : on garde la version connue, même ancienne

    save_game(product || Product.new(kind: "game", igdb_id: igdb_id), game)
  rescue ActiveRecord::RecordNotUnique
    # Deux enregistrements simultanés du même jeu : l'autre a créé l'œuvre juste avant nous
    Product.find_by(igdb_id: igdb_id)
  end

  # Film par son identifiant TMDB : déjà au catalogue et récent, sinon lu chez Wikidata (CC0), résumé chez Wikipédia.
  # Rien de TMDB n'est conservé (leurs conditions l'interdisent au-delà de 6 mois), sauf l'identifiant.
  # nil si Wikidata ne connaît pas le film (et qu'il n'est pas déjà au catalogue)
  def self.movie(tmdb_id)
    tmdb_id = positive_id(tmdb_id)
    return nil unless tmdb_id

    product = Product.find_by(tmdb_id: tmdb_id)
    return product if product && !product.stale?

    movie = WikimediaService.movie(tmdb_id)
    return product unless movie

    product ||= Product.find_by(wikidata_id: movie[:wikidata_id]) || Product.new(kind: "movie")
    save_movie(product, tmdb_id, movie)
  rescue ActiveRecord::RecordNotUnique
    Product.find_by(tmdb_id: tmdb_id)
  end

  # Livre (l'œuvre, pas l'édition) par son identifiant Wikidata, retrouvé à partir du titre et de l'auteur lus à la BnF.
  # Résumé de Wikipédia s'il existe ; sinon le résumé généré par Claude sera gardé ici (BookDescriptionJob).
  # nil si Wikidata ne répond pas ou si ce n'est pas une œuvre littéraire (et qu'elle n'est pas déjà au catalogue)
  def self.book(wikidata_id)
    # kind : l'identifiant vient du navigateur, il ne doit pas pouvoir renvoyer un film du catalogue
    product = Product.find_by(wikidata_id: wikidata_id.to_s, kind: "book")
    return product if product && !product.stale?

    book = WikimediaService.book(wikidata_id)
    return product unless book

    save_book(product || Product.new(kind: "book"), book)
  rescue ActiveRecord::RecordNotUnique
    Product.find_by(wikidata_id: wikidata_id.to_s, kind: "book")
  end

  # Identifiant numérique strictement positif, nil sinon (il vient du navigateur)
  def self.positive_id(id)
    id = Integer(id.to_s, exception: false)
    id if id&.positive?
  end

  def self.save_movie(product, tmdb_id, movie)
    summary = WikimediaService.summary(movie[:wikipedia_title])
    product.update!(
      tmdb_id: tmdb_id,
      wikidata_id: movie[:wikidata_id],
      title: movie[:title],
      original_title: (movie[:original_title] if movie[:original_title] != movie[:title]),
      release_year: movie[:release_year],
      creator: movie[:directors].join(", ").presence,
      # Wikipédia muet (panne passagère) au rafraîchissement : on garde le résumé déjà connu
      description: summary&.dig(:text) || product.description,
      description_source: summary ? "wikipedia" : product.description_source,
      details: product.details.merge("studios" => movie[:studios],
                                     "wikipedia_url" => summary&.dig(:url) || product.details["wikipedia_url"]),
      fetched_at: Time.current
    )
    product
  end

  def self.save_book(product, book)
    summary = WikimediaService.summary(book[:wikipedia_title])
    product.update!(
      wikidata_id: book[:wikidata_id],
      title: book[:title],
      original_title: (book[:original_title] if book[:original_title] != book[:title]),
      release_year: book[:release_year],
      creator: book[:authors].join(", ").presence,
      # Pas d'article Wikipédia : on garde le résumé déjà connu (Wikipédia muet, ou résumé généré par Claude)
      description: summary&.dig(:text) || product.description,
      description_source: summary ? "wikipedia" : product.description_source,
      details: product.details.merge("genres" => book[:genres],
                                     "wikipedia_url" => summary&.dig(:url) || product.details["wikipedia_url"]),
      fetched_at: Time.current
    )
    product
  end

  def self.save_game(product, game)
    french = IgdbService.french_title(game)
    summary_en = game["summary"].presence
    # Résumé anglais modifié chez IGDB : l'ancienne traduction ne correspond plus, elle sera refaite
    product.description = nil if product.persisted? && product.details["summary_en"] != summary_en

    product.update!(
      title: french || game["name"],
      original_title: (game["name"] if french && french != game["name"]),
      release_year: IgdbService.release_date(game)&.year,
      creator: IgdbService.developers(game).join(", ").presence,
      details: product.details.merge(
        "summary_en" => summary_en,
        "genres" => game["genres"].to_a.pluck("name"),
        "platforms" => game["platforms"].to_a.pluck("name")
      ),
      fetched_at: Time.current
    )
    product
  end
  private_class_method :positive_id, :save_game, :save_movie, :save_book
end
