class BookDescriptionJob < ApplicationJob
  queue_as :default
  # API indisponible ou réponse invalide : on réessaie plus tard (≈ 3s, 18s, 83s, 4min)
  retry_on AnthropicClient::Error, wait: :polynomially_longer, attempts: 5

  # Génère un résumé pour un livre ajouté sans description
  def perform(item_id)
    item = Item.find_by(id: item_id)
    return unless item
    return unless item.item_detailable_type == "BookDetail"

    detail = item.item_detailable
    return if detail.description.present?

    # Résumé déjà connu pour cette œuvre (Wikipédia, ou généré pour quelqu'un d'autre entre-temps) : repris
    product = item.product
    return detail.update(description: product.description) if product&.description.present?

    description = BookDescriptionService.generate(title: item.title, author: detail.author, isbn: detail.isbn)
    return if description.blank?

    detail.update(description: description)
    # Généré une fois pour tout le monde : les prochains ajouts de ce livre le reprendront
    product&.update(description: description, description_source: "claude_generated")
  end
end
