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

    translated = TranslationService.translate_batch([ detail.summary_en ]).first
    detail.update(description: translated) if translated.present?
  end
end
