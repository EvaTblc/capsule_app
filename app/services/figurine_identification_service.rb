class FigurineIdentificationService
  # Signatures binaires des formats d'image acceptés par l'API Claude
  IMAGE_SIGNATURES = {
    "\xFF\xD8\xFF".b => "image/jpeg",
    "\x89PNG\r\n\x1A\n".b => "image/png",
    "GIF87a".b => "image/gif",
    "GIF89a".b => "image/gif"
  }.freeze

  # Type réel d'une image d'après ses premiers octets (nil si format non pris en charge, ex. HEIC)
  def self.media_type_of(bytes)
    bytes = bytes.b
    return "image/webp" if bytes[0, 4] == "RIFF" && bytes[8, 4] == "WEBP"

    IMAGE_SIGNATURES.find { |signature, _| bytes.start_with?(signature) }&.last
  end

  def self.identify(base64_image, media_type: "image/jpeg")
    AnthropicClient.json([
      {
        type: "image",
        source: {
          type: "base64",
          media_type: media_type,
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
