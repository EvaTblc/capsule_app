class Item < ApplicationRecord
  belongs_to :item_detailable, polymorphic: true, dependent: :destroy
  belongs_to :collection
  # L'œuvre du catalogue partagé, quand on l'a identifiée (jeu, film ou livre choisi via la recherche ou le scan)
  belongs_to :product, optional: true

  # :thumb : vignette des grilles et listes (2× la taille affichée, pour les écrans haute densité), au lieu de la photo
  # d'origine (souvent plusieurs Mo). Préparée en tâche de fond dès l'ajout de la photo
  has_many_attached :images do |attachable|
    attachable.variant :thumb, resize_to_fill: [ 300, 400 ], preprocessed: true
  end

  CONDITIONS = [ "Neuf", "Très bon état", "Bon état", "Correct", "Mauvais état" ].freeze

  validates :title, presence: true

  # Type de l'item (« BookDetail », « VideoGameDetail »...) : celui de son détail, seule source de vérité
  def item_type
    item_detailable_type
  end
  # L'état reste facultatif : l'ajout rapide de jeux n'en demande pas
  validates :condition, inclusion: { in: CONDITIONS }, allow_blank: true

  ITEM_TYPE_STYLES = {
  "BookDetail"      => "bg-emerald-50 shadow-emerald-100",
  "VideoGameDetail" => "bg-blue-50 shadow-blue-100",
  "MovieDetail"     => "bg-red-50 shadow-red-100",
  "MusicDetail"     => "bg-pink-50 shadow-pink-100",
  "FigurineDetail"  => "bg-orange-50 shadow-orange-100",
  "TcgDetail"       => "bg-yellow-50 shadow-yellow-100",
  "BoardGameDetail" => "bg-purple-50 shadow-purple-100"
  }

  # Types en cours de refonte : plus proposés ni acceptés à la création (pas de nouvelles fiches incomplètes en base).
  # Les items existants de ce type restent visibles et modifiables. Figurine : formulaire à revoir (2026-11-24)
  HIDDEN_TYPES = %w[FigurineDetail].freeze

  TYPE_TO_ICON = {
    "BookDetail"      => "book",
    "VideoGameDetail" => "video_games",
    "MovieDetail"     => "movies",
    "MusicDetail"     => "music",
    "FigurineDetail"  => "figurines",
    "TcgDetail"       => "trading_cards",
    "BoardGameDetail" => "board_games"
  }
end
