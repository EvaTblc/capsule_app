# Fiche d'un item (style « Pilule ») : couleur du haut selon le type, pastilles des infos clés sous le titre
module ItemsHelper
  # Fond du haut de la fiche : même teinte que le type d'item ailleurs dans l'appli (vignettes, formulaire), un cran plus marqué
  ITEM_PAGE_TINTS = {
    "BookDetail"      => "bg-emerald-100",
    "VideoGameDetail" => "bg-blue-100",
    "MovieDetail"     => "bg-red-100",
    "MusicDetail"     => "bg-pink-100",
    "FigurineDetail"  => "bg-orange-100",
    "TcgDetail"       => "bg-yellow-100",
    "BoardGameDetail" => "bg-purple-100"
  }.freeze

  # Champs du détail montrés en pastilles sous le titre : retirés de la liste des infos pour ne pas les répéter
  ITEM_CHIP_FIELDS = {
    "VideoGameDetail" => %w[platform completed],
    "MovieDetail"     => %w[format],
    "FigurineDetail"  => %w[is_complete]
  }.freeze

  def item_page_tint(item) = ITEM_PAGE_TINTS.fetch(item.item_detailable_type, "bg-gray-100")

  def item_chip_fields(item) = ITEM_CHIP_FIELDS.fetch(item.item_detailable_type, [])

  # Pastilles sous le titre, dans l'ordre : support (couleur de son bandeau), « Complet », état.
  # kind : :band (couleur du support, texte blanc), :ink (fait positif), :outline (info neutre)
  def item_page_chips(item)
    detail = item.item_detailable
    chips = []
    case detail
    when VideoGameDetail
      chips << { label: detail.platform, kind: :band, color: platform_band_color(detail.platform) } if detail.platform.present?
      chips << { label: "Complet", kind: :ink } if detail.completed?
    when MovieDetail
      chips << { label: detail.format, kind: :band, color: format_band_color(detail.format) } if detail.format.present?
    when FigurineDetail
      chips << { label: "Complète", kind: :ink } if detail.is_complete?
    end
    chips << { label: item.condition, kind: :outline } if item.condition.present?
    chips
  end
end
