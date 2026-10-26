module ApplicationHelper
  # Token Mapbox affiché dans les pages (carte) : visible par tous dans le code source, il doit être
  # restreint aux URL du site dans Mapbox. Le géocodage serveur utilise un autre token (voir geocoder.rb).
  # Repli sur l'ancien token commun tant que mapbox.public_token n'est pas dans les credentials.
  def mapbox_public_token
    Rails.application.credentials.dig(:mapbox, :public_token) || Rails.application.credentials.dig(:mapbox, :api_key)
  end
end
