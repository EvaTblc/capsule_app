class TranslationJob < ApplicationJob
  queue_as :default
  # API indisponible ou réponse invalide : on réessaie plus tard (≈ 3s, 18s, 83s, 4min)
  retry_on TranslationService::Error, wait: :polynomially_longer, attempts: 5

  def perform(item_id)
    item = Item.find_by(id: item_id)
    return unless item
    return unless item.item_detailable_type == "VideoGameDetail"

    detail = item.item_detailable
    return if detail.description.present?
    return if detail.summary_en.blank?

    # Déjà traduit pour une autre personne entre-temps : on reprend la traduction de l'œuvre
    product = item.product
    return detail.update(description: product.description) if product&.description.present?

    translated = TranslationService.translate_batch([ detail.summary_en ]).first
    return if translated.blank?

    detail.update(description: translated)
    # Traduit une fois pour tout le monde : les prochains ajouts de ce jeu la reprendront
    product&.update(description: translated, description_source: "igdb_translated")
  end
end
