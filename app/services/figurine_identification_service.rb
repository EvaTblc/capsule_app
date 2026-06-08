class FigurineIdentificationService
  ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages"

  def self.identify(base64_image)
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
        messages: [
          {
            role: "user",
            content: [
              {
                type: "image",
                source: {
                  type: "base64",
                  media_type: "image/jpeg",
                  data: base64_image
                }
              },
              {
                type: "text",
                text: "Identifie cette figurine de collection. Réponds UNIQUEMENT avec un JSON valide, sans markdown, sans backticks :
{\"title\": \"nom du personnage et série\", \"name\": \"nom du personnage\", \"series\": \"nom de la séries et/ou franchise\", \"manufacturer\": \"information fabricant\", \"line\": \"information sur la gamme\",  \"release_year\": \"année de lancement de la gamme/ligne de cette figurine, pas l'année de fabrication de cet exemplaire spécifique\"}
Si tu ne peux pas identifier un champ, mets null."
              }
            ]
          }
        ]
      }
    )

    result = JSON.parse(response.body.to_s)
    raw = result.dig("content", 0, "text").to_s
    cleaned = raw.gsub(/```json\n?|\n?```/, "").strip
    JSON.parse(cleaned)
  rescue => e
    Rails.logger.error("[FigurineIdentificationService] Erreur: #{e.message}")
    {}
  end
end
