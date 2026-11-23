module ApplicationHelper
  # « Jeux vidéo », « Livres »... : nom affiché d'une catégorie de collection (clé du code : video_games, books...)
  def category_label(category)
    t("categories.#{category}", default: category.to_s.humanize)
  end

  # « Jeu vidéo », « Livre »... : nom affiché d'un type d'item (VideoGameDetail, BookDetail...)
  def item_type_label(type)
    t("item_types.#{type}", default: type.to_s.delete_suffix("Detail").titleize)
  end

  # « 0 item », « 1 item », « 3 items » (en français, 0 et 1 sont au singulier)
  def items_count(count)
    t("items.count", count: count)
  end

  # Token Mapbox affiché dans les pages (carte) : visible par tous dans le code source, il est restreint
  # aux URL du site dans Mapbox. Le géocodage serveur utilise un autre token (voir geocoder.rb).
  def mapbox_public_token
    Rails.application.credentials.dig(:mapbox, :public_token)
  end
end
