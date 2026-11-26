# Pages de collections (style « Pilule »)
module CollectionsHelper
  # Fond de l'en-tête d'une collection : la teinte de sa catégorie (Collection::CATEGORY_STYLES), un cran plus marquée,
  # comme le haut de la fiche d'un item du même type (ItemsHelper::ITEM_PAGE_TINTS)
  COLLECTION_TINTS = {
    "movies"        => "bg-red-100",
    "music"         => "bg-pink-100",
    "video_games"   => "bg-blue-100",
    "figurines"     => "bg-orange-100",
    "trading_cards" => "bg-yellow-100",
    "board_games"   => "bg-purple-100",
    "books"         => "bg-emerald-100",
    "mixed"         => "bg-purple-100",
    "other"         => "bg-stone-200"
  }.freeze

  def collection_tint(category) = COLLECTION_TINTS.fetch(category, "bg-stone-200")
end
