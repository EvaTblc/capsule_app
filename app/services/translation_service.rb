class TranslationService
  class Error < StandardError; end

  # Renvoie les traductions dans le même ordre que texts.
  # Lève TranslationService::Error si la traduction échoue : à l'appelant de décider quoi faire.
  def self.translate_batch(texts, target_language: "français")
    return texts if texts.all?(&:blank?)

    translations = AnthropicClient.json(
      "Traduis chaque texte de ce tableau JSON en #{target_language}, en conservant les paragraphes. " \
      "Réponds UNIQUEMENT avec un tableau JSON de chaînes, dans le même ordre, sans markdown ni commentaire.\n\n" \
      "#{texts.to_json}",
      # Marge pour la réflexion, et pour le tokenizer de Haiku 5.5 (~30 % de tokens en plus pour le même texte)
      max_tokens: 8192
    )

    unless translations.is_a?(Array) && translations.size == texts.size
      raise Error, "Réponse inattendue : #{translations.to_json.truncate(200)}"
    end

    translations
  rescue AnthropicClient::Error => e
    raise Error, e.message
  end
end
