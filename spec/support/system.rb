# Tests système : un vrai Chrome sans interface, piloté par Cuprite, clique dans l'appli.
#
# Chrome est cherché automatiquement (CI GitHub : déjà installé). En local, sans Chrome installé :
#   BROWSER_PATH=/chemin/vers/chrome-headless-shell bundle exec rspec spec/system
require "capybara/cuprite"

Capybara.register_driver(:cuprite_capsule) do |app|
  Capybara::Cuprite::Driver.new(
    app,
    browser_path: ENV["BROWSER_PATH"].presence,
    headless: true,
    # Taille d'un téléphone : l'appli est pensée pour le mobile
    window_size: [ 390, 844 ],
    process_timeout: 30,
    timeout: 15,
    # Chrome ne parle qu'à l'appli testée : Mapbox, unpkg... sont bloqués.
    # Tests fiables (pas de dépendance à Internet) et aucun site extérieur chargé
    url_whitelist: [ %r{\Ahttps?://(127\.0\.0\.1|localhost)(:\d+)?/} ],
    # Le bac à sable de Chrome n'est pas disponible dans certains conteneurs de CI
    browser_options: ENV["CI"] ? { "no-sandbox" => nil } : {}
  )
end

Capybara.default_max_wait_time = 5

# Sans Chrome (ex. poste de dev sans navigateur), les tests système sont ignorés au lieu d'échouer.
# En CI, Chrome est toujours disponible : ils tournent à chaque push.
CHROME_AVAILABLE = ENV["BROWSER_PATH"].present? || ENV["CI"].present? ||
                   %w[google-chrome google-chrome-stable chromium chromium-browser].any? { |bin| system("which #{bin} > /dev/null 2>&1") }

RSpec.configure do |config|
  unless CHROME_AVAILABLE
    config.filter_run_excluding type: :system
    config.before(:suite) { warn "\n⚠️  Tests système ignorés : Chrome introuvable (définis BROWSER_PATH pour les lancer)\n" }
  end

  config.include Devise::Test::IntegrationHelpers, type: :system

  config.before(:each, type: :system) do
    driven_by :cuprite_capsule
  end
end
