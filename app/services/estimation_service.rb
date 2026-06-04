class EstimationService
  ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages"

  def self.estimate(item)
    attributes = item.detailable.attributes.except(
      "id", "created_at", "updated_at", "synopsis", "description", "duration").map { |k, v| "#{k} : #{v}" }.join("\n")

    prompt = "Tu es un expert en estimation de valeur de produits d'occasion.
Donne une fourchette de prix réaliste en euros pour cet item sur le marché français de l'occasion (Vinted, LeBonCoin...) :

Nom : #{item.title}
État : #{item.condition}
#{attributes}

Réponds uniquement avec la fourchette de prix et une phrase d'explication courte."

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
    result.dig("content", 0, "text").to_s
  rescue => e
    Rails.logger.error("[EstimationService] Erreur: #{e.message}")
    "Estimation indisponible"
  end
end
