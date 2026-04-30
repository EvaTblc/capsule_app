class TranslationService
  ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages"

  def self.translate_batch(texts, target_language: "français")
    return texts if texts.all?(&:blank?)

    numbered = texts.each_with_index.map { |t, i| "#{i + 1}. #{t}" }.join("\n\n")

    response = HTTP.post(
      ANTHROPIC_API_URL,
      headers: {
        "x-api-key" => Rails.application.credentials.anthropic[:api_key],
        "anthropic-version" => "2023-06-01",
        "content-type" => "application/json"
      },
      json: {
        model: "claude-haiku-4-5-20251001",
        max_tokens: 2048,
        messages: [
          {
            role: "user",
            content: "Traduis ces textes en #{target_language}. Réponds UNIQUEMENT avec les traductions numérotées dans le même format, sans commentaire.\n\n#{numbered}"
          }
        ]
      }
    )

    result = JSON.parse(response.body.to_s)
    translated = result.dig("content", 0, "text").to_s

    # Parser les lignes numérotées
    lines = translated.split(/\n\n|\n(?=\d+\.)/).map(&:strip)
    lines.map { |l| l.sub(/^\d+\.\s*/, "") }
  rescue => e
    Rails.logger.error("[TranslationService] Erreur: #{e.message}")
    texts
  end
end
