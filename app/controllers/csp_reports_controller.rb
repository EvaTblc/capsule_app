# Reçoit les violations de Content Security Policy envoyées par les navigateurs et les logue.
# Sert à vérifier, en mode rapport, que la politique ne bloquerait rien de légitime.
class CspReportsController < ActionController::API
  # Endpoint public appelé par les navigateurs : on limite pour éviter de saturer les logs
  rate_limit to: 30, within: 1.minute

  def create
    report = JSON.parse(request.raw_post).fetch("csp-report", {}) rescue {}
    Rails.logger.warn(
      "[CSP] #{report["violated-directive"] || report["effective-directive"]} " \
      "bloquerait #{report["blocked-uri"].to_s.truncate(200)} sur #{report["document-uri"].to_s.truncate(200)}"
    )
    head :no_content
  end
end
