class EstimationService
  DEFAULT_ESTIMATION = { "price" => "N/A", "explanation" => "Estimation indisponible" }.freeze

  def self.estimate(item)
    attributes = item.item_detailable.attributes.except(
      "id", "created_at", "updated_at", "synopsis", "description", "duration").map { |k, v| "#{k} : #{v}" }.join("\n")

  prompt = "Tu es un expert en estimation de valeur de produits d'occasion.
  Donne une fourchette de prix réaliste en euros pour cet item sur le marché français de l'occasion (Vinted, LeBonCoin...) :

  Nom : #{item.title}
  État : #{item.condition}
  #{attributes}

  Réponds UNIQUEMENT avec un JSON valide, sans markdown, sans backticks, exactement dans ce format :
  {\"price\": \"15€ - 25€\", \"explanation\": \"Une phrase d'explication courte.\"}"

    AnthropicClient.json(prompt)
  rescue AnthropicClient::Error => e
    Rails.logger.error("[EstimationService] Erreur: #{e.message}")
    DEFAULT_ESTIMATION.dup
  end
end
