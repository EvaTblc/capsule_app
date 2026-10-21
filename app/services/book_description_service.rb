class BookDescriptionService
  # Lève AnthropicClient::Error si la génération échoue : BookDescriptionJob réessaie alors plus tard
  def self.generate(title:, author: nil, isbn: nil)
    prompt = "Génère un résumé court (3-4 phrases max) du livre '#{title}'#{author.present? ? " de #{author}" : ""}#{isbn.present? ? " (ISBN: #{isbn})" : ""}.
    Réponds UNIQUEMENT avec le résumé en français, sans introduction, sans titre, sans guillemets."

    AnthropicClient.text(prompt)
  end
end
