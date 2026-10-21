class FigurineIdentificationService
  def self.identify(base64_image)
    AnthropicClient.json([
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
    ])
  rescue AnthropicClient::Error => e
    Rails.logger.error("[FigurineIdentificationService] Erreur: #{e.message}")
    {}
  end
end
