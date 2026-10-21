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

    description = BookDescriptionService.generate(title: item.title, author: detail.author, isbn: detail.isbn)
    detail.update(description: description) if description.present?
  end
end
