class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Pages d'un utilisateur connecté : Cache-Control: no-store, le navigateur ne les garde jamais.
  # Sinon, après une déconnexion, le bouton « retour » réaffiche des pages privées (appareil partagé).
  before_action :no_store, if: :user_signed_in?

  PAID_FEATURE_MESSAGE = "Cette fonction est réservée aux comptes Premium.".freeze

  private

  # Fonctions qui coûtent de l'argent (Claude, UPCitemdb) : comptes admin et premium uniquement.
  # 403 : connecté, mais pas le droit. premium: true permet au JavaScript d'afficher le bon message.
  # À placer avant un rate_limit, pour qu'un compte free ne consomme pas le quota pour rien.
  def require_paid_features
    return if current_user.paid_features?

    if request.format.turbo_stream?
      # Seule l'estimation (fiche d'item) répond en turbo_stream : le message remplace le bouton
      render turbo_stream: turbo_stream.update("estimation", html: helpers.tag.p(PAID_FEATURE_MESSAGE, class: "text-sm text-gray-500")),
             status: :forbidden
    else
      render json: { error: PAID_FEATURE_MESSAGE, premium: true }, status: :forbidden
    end
  end
end
