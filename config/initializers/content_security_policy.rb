# Be sure to restart your server when you modify this file.

# Content Security Policy : liste des sources autorisées pour les scripts, styles, images...
# Si une faille XSS laissait passer un script injecté, le navigateur refuserait de l'exécuter.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    # Scripts : l'appli (importmap + nonce pour les scripts en ligne), Mapbox GL, Lottie (version figée + SRI),
    # jspm (modules mapbox-gl et process pinnés dans config/importmap.rb)
    policy.script_src :self, "https://api.mapbox.com", "https://unpkg.com", "https://ga.jspm.io"
    # Styles : unsafe-inline nécessaire pour les attributs style= et les styles injectés par Turbo et Mapbox
    policy.style_src :self, :unsafe_inline, "https://api.mapbox.com"
    # Images : couvertures (Cloudinary, IGDB, TMDB), avatars Google, aperçus locaux (data:, blob:)
    policy.img_src :self, :https, :data, :blob
    policy.font_src :self, :data
    # Requêtes JS : l'appli, et Mapbox (tuiles, itinéraires, statistiques)
    policy.connect_src :self, "https://api.mapbox.com", "https://events.mapbox.com"
    # Mapbox GL dessine la carte dans des workers créés en blob:
    policy.worker_src :self, :blob
    policy.child_src :self, :blob
    policy.object_src :none
    policy.base_uri :self
    # La connexion Google part d'un formulaire de l'appli puis redirige vers Google
    policy.form_action :self, "https://accounts.google.com"
    # Personne ne peut afficher l'appli dans une iframe (protection contre le clickjacking)
    policy.frame_ancestors :none
    # Violations envoyées à l'appli, qui les logue (voir CspReportsController)
    policy.report_uri "/csp-violations"
  end

  # Nonce pour les scripts en ligne (importmap, enregistrement du service worker) : seuls ceux
  # générés par le serveur pour cette page portent le bon nonce
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]

  # MODE RAPPORT : le navigateur ne bloque rien, il signale seulement les violations.
  # Quand les logs ne montrent plus de « [CSP] » légitime, passer à false pour bloquer réellement.
  config.content_security_policy_report_only = true
end
