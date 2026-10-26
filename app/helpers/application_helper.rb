module ApplicationHelper
  # Token Mapbox affiché dans les pages (carte) : visible par tous dans le code source, il est restreint
  # aux URL du site dans Mapbox. Le géocodage serveur utilise un autre token (voir geocoder.rb).
  def mapbox_public_token
    Rails.application.credentials.dig(:mapbox, :public_token)
  end
end
