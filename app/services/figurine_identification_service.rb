class FigurineIdentificationService
  # Signatures binaires des formats d'image acceptés par l'API Claude
  IMAGE_SIGNATURES = {
    "\xFF\xD8\xFF".b => "image/jpeg",
    "\x89PNG\r\n\x1A\n".b => "image/png",
    "GIF87a".b => "image/gif",
    "GIF89a".b => "image/gif"
  }.freeze

  # Limite de l'API Claude par image ; le navigateur réduit la photo bien en dessous avant l'envoi
  MAX_IMAGE_BYTES = 5.megabytes

  # Résultat d'une identification : data (champs reconnus) ou error + status HTTP à renvoyer
  Result = Struct.new(:data, :error, :status, keyword_init: true)

  # Vérifie la photo envoyée par le navigateur (en base64), puis l'identifie.
  # Une photo refusée (illisible, trop lourde, format inconnu) ne déclenche aucun appel payant.
  def self.identify_upload(base64_image)
    image = Base64.strict_decode64(base64_image.to_s) rescue nil
    return Result.new(error: "Photo illisible, réessaie.", status: :unprocessable_entity) if image.blank?
    if image.bytesize > MAX_IMAGE_BYTES
      return Result.new(error: "Photo trop lourde, réessaie avec une photo plus petite.", status: 413)
    end

    # Le vrai format, lu dans le fichier : l'API Claude refuse une image déclarée sous un autre type
    media_type = media_type_of(image)
    unless media_type
      return Result.new(error: "Format de photo non pris en charge (JPEG, PNG, WebP ou GIF).", status: :unprocessable_entity)
    end

    data = identify(base64_image, media_type: media_type)
    # Échec de l'appel, ou réponse dont tous les champs sont null : rien de reconnu
    unless data.is_a?(Hash) && data.values.any?(&:present?)
      return Result.new(error: "Figurine non reconnue : remplis les champs à la main.", status: :unprocessable_entity)
    end

    Result.new(data: data)
  end

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
