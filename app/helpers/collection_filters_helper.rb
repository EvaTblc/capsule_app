# Recherche, filtres rapides et tri de la page d'une collection (collection_filter_controller.js).
# Les valeurs des filtres et du tri sont calculées ici et posées en data-* sur chaque item : le navigateur filtre
# et trie sans recharger la page.
module CollectionFiltersHelper
  # Critère des filtres rapides selon la catégorie : celui qui sépare le mieux une collection de ce type
  def item_facet(item, category)
    detail = item.item_detailable
    value = case category
    when "video_games" then detail.try(:platform)
    when "movies", "music" then detail.try(:format)
    when "books" then detail.try(:genre)
    when "figurines" then detail.try(:manufacturer)
    when "trading_cards" then detail.try(:game)
    when "mixed", "other" then item_type_label(item.item_detailable_type)
    end
    value.presence
  end

  # Valeurs proposées en filtres rapides : celles présentes dans la collection, dans l'ordre naturel
  # (« Tome 2 » avant « Tome 10 »). Un seul choix possible : pas de filtre
  def collection_facets(items, category)
    values = items.filter_map { |item| item_facet(item, category) }.uniq.sort_by { |value| NaturalSort.key(value) }
    values.size > 1 ? values : []
  end

  # Filtre « Complets » : seulement si au moins un item de la collection l'est (jeux, figurines)
  def collection_completable?(items)
    items.any? { |item| item_tile_badge(item) }
  end

  # Tris proposés : titre, ajout, puis l'info affichée sous le titre (plateforme, auteur...) quand elle a un nom
  SECONDARY_SORTS = { "video_games" => "Plateforme", "books" => "Auteur", "movies" => "Format", "music" => "Artiste",
                      "figurines" => "Fabricant", "trading_cards" => "Extension", "mixed" => "Type", "other" => "Type" }.freeze

  def collection_sort_options(category)
    options = [ [ "Titre A → Z", "title" ], [ "Ajoutés récemment", "recent" ] ]
    options << [ SECONDARY_SORTS[category], "secondary" ] if SECONDARY_SORTS[category]
    options
  end

  # Clé du tri secondaire : le type pour une collection « Divers », sinon l'info affichée sous le titre
  def item_secondary_sort(item, category)
    value = %w[mixed other].include?(category) ? item_type_label(item.item_detailable_type) : item_tile_subtitle(item)
    I18n.transliterate(value.to_s).downcase
  end

  # Texte où cherche la recherche : titre et info sous le titre (auteur, plateforme...), sans accents ni majuscules
  def item_search_text(item)
    I18n.transliterate([ item.title, item_tile_subtitle(item) ].compact.join(" ")).downcase
  end
end
