class BookDescriptionService
  ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages"

  def self.generate(title:, author: nil, isbn: nil)
    prompt = "Génère un résumé court (3-4 phrases max) du livre '#{title}'#{author.present? ? " de #{author}" : ""}#{isbn.present? ? " (ISBN: #{isbn})" : ""}.
    Réponds UNIQUEMENT avec le résumé en français, sans introduction, sans titre, sans guillemets."

    response = HTTP.post(
      ANTHROPIC_API_URL,
      headers: {
        "x-api-key" => Rails.application.credentials.anthropic[:api_key],
        "anthropic-version" => "2023-06-01",
        "content-type" => "application/json"
      },
      json: {
        model: "claude-haiku-4-5-20251001",
        max_tokens: 256,
        messages: [{ role: "user", content: prompt }]
      }
    )

    result = JSON.parse(response.body.to_s)
    result.dig("content", 0, "text").to_s.strip
  rescue => e
    Rails.logger.error("[BookDescriptionService] Erreur: #{e.message}")
    nil
  end
end
