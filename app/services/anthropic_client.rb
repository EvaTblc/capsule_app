class AnthropicClient
  MODEL = "claude-haiku-5-5"
  # Haiku 5.5 réfléchit avant de répondre, et cette réflexion compte dans max_tokens :
  # on laisse de la marge (256 suffisait sur Haiku 4.5), et on garde l'effort au plus bas,
  # adapté à nos tâches courtes et fréquentes (moins de réflexion = plus rapide et moins cher)
  DEFAULT_MAX_TOKENS = 2048
  EFFORT = :low

  class Error < StandardError; end

  # Client du SDK officiel, partagé par toute l'appli.
  # Il réessaie tout seul 2 fois en cas d'erreur passagère (429, 5xx, API surchargée, coupure réseau).
  def self.sdk
    @sdk ||= Anthropic::Client.new(
      api_key: Rails.application.credentials.dig(:anthropic, :api_key),
      timeout: 60, # défaut du SDK : 600 s, bien trop long pour une requête web
      max_retries: 2
    )
  end

  # Envoie un message à Claude et renvoie le texte de sa réponse.
  # content : une chaîne, ou un tableau de blocs (ex : image + texte).
  # Lève AnthropicClient::Error si l'appel échoue.
  def self.text(content, max_tokens: DEFAULT_MAX_TOKENS)
    message = sdk.messages.create(
      model: MODEL,
      max_tokens: max_tokens,
      output_config: { effort: EFFORT },
      messages: [ { role: "user", content: content } ]
    )

    # Refus des filtres de sécurité : réponse HTTP 200 sans contenu utile (pas de modèle de repli sur Haiku 5.5)
    if message.stop_reason == :refusal
      raise Error, "Requête refusée par Claude (#{message.stop_details&.category || 'sans catégorie'})"
    end
    # Réponse coupée : un JSON ou une traduction tronqués sont inutilisables
    raise Error, "Réponse tronquée (max_tokens = #{max_tokens} atteint)" if message.stop_reason == :max_tokens

    # La réponse peut commencer par des blocs de réflexion : on ne garde que le texte
    message.content.select { |block| block.type == :text }.map(&:text).join.strip
  rescue Anthropic::Errors::Error => e
    raise Error, "#{e.class}: #{e.message}"
  end

  # Comme text, pour une réponse attendue en JSON (on retire d'éventuelles balises ```json).
  def self.json(content, max_tokens: DEFAULT_MAX_TOKENS)
    raw = text(content, max_tokens: max_tokens)
    JSON.parse(raw.gsub(/```json\n?|\n?```/, "").strip)
  rescue JSON::ParserError
    raise Error, "Réponse non JSON : #{raw.truncate(200)}"
  end
end
