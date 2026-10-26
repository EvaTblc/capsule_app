class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Pages d'un utilisateur connecté : Cache-Control: no-store, le navigateur ne les garde jamais.
  # Sinon, après une déconnexion, le bouton « retour » réaffiche des pages privées (appareil partagé).
  before_action :no_store, if: :user_signed_in?
end
