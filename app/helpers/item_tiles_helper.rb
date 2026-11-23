# Vignettes d'items (grille, liste, « Récemment ajouté ») : ta photo, sinon une vignette générique propre au type
# (tranche de livre, boîtier de jeu avec le bandeau de sa plateforme, boîtier de film...).
# Les couleurs passent en style en ligne : elles dépendent des données, pas de classes Tailwind fixes.
module ItemTilesHelper
  # Bandeau des boîtiers de jeux : couleur associée à la plateforme (texte blanc lisible sur chacune)
  PLATFORM_BANDS = {
    "Switch 2" => "#b91c1c", "Switch" => "#dc2626", "Nintendo 3DS" => "#be123c", "Nintendo DS" => "#4b5563",
    "Wii U" => "#0369a1", "Wii" => "#64748b", "Gamecube" => "#5b21b6", "Nintendo 64" => "#15803d",
    "Super Nintendo" => "#6d28d9", "Game Boy Advance" => "#4338ca", "Game Boy Color" => "#a21caf", "Game Boy" => "#57534e",
    "PS5" => "#1d4ed8", "PS4" => "#1e3a8a", "PS3" => "#111827", "PS2" => "#1e40af", "PS1" => "#374151",
    "Xbox Series" => "#15803d", "Xbox One" => "#166534", "Xbox 360" => "#4d7c0f", "Xbox" => "#14532d",
    "Mega Drive" => "#111827", "Game Gear" => "#1f2937", "PC" => "#334155"
  }.freeze
  DEFAULT_BAND = "#475569".freeze

  # Bandeau des boîtiers de films, selon le support
  FORMAT_BANDS = { "Blu-ray" => "#1d4ed8", "Blu-ray 3D" => "#1e40af", "4K UHD" => "#111827", "DVD" => "#000000", "VHS" => "#57534e" }.freeze

  def platform_band_color(platform)
    PLATFORM_BANDS.fetch(platform.to_s, DEFAULT_BAND)
  end

  def format_band_color(format)
    FORMAT_BANDS.fetch(format.to_s, DEFAULT_BAND)
  end

  # Badge sur la vignette : seulement une info positive (« Complet »), jamais un manque
  def item_tile_badge(item)
    detail = item.item_detailable
    case detail
    when VideoGameDetail then "Complet" if detail.completed?
    when FigurineDetail then "Complète" if detail.is_complete?
    end
  end

  # Ligne sous le titre : l'info la plus utile pour reconnaître l'item, selon son type
  def item_tile_subtitle(item)
    detail = item.item_detailable
    parts = case detail
    when VideoGameDetail then [ detail.platform ]
    when BookDetail then [ detail.author ]
    when MovieDetail then [ detail.format, detail.year ]
    when MusicDetail then [ detail.artist, detail.format ]
    when FigurineDetail then [ detail.manufacturer, detail.line ]
    when TcgDetail then [ detail.card_set, detail.card_number ]
    when BoardGameDetail then [ detail.publisher ]
    else []
    end
    parts.compact_blank.join(" · ").presence
  end

  # « 2–5 joueurs », « 2 joueurs », nil
  def board_game_players(detail)
    min, max = detail.min_players, detail.max_players
    return nil unless min || max
    return "#{min || max} joueur#{'s' if (min || max) > 1}" if min == max || min.nil? || max.nil?

    "#{min}–#{max} joueurs"
  end
end
