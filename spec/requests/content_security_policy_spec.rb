require "rails_helper"

RSpec.describe "Content Security Policy", type: :request do
  let(:user) { create(:user) }
  before do
    sign_in user
    get collections_path
  end

  def policy = response.headers["Content-Security-Policy-Report-Only"]

  it "est envoyée en mode rapport (rien n'est bloqué tant qu'on n'a pas validé)" do
    expect(policy).to include("default-src 'self'", "object-src 'none'", "frame-ancestors 'none'", "report-uri /csp-violations")
    expect(response.headers["Content-Security-Policy"]).to be_nil
  end

  it "chaque script en ligne porte le nonce de la page (sinon il serait bloqué)" do
    nonce = policy[/'nonce-([^']+)'/, 1]
    expect(nonce).to be_present
    inline_scripts = Nokogiri::HTML(response.body).css("script:not([src])")
    expect(inline_scripts).not_to be_empty
    expect(inline_scripts.map { |script| script["nonce"] }.uniq).to eq([ nonce ])
  end

  it "il ne reste aucun gestionnaire d'événement en ligne (onclick, onerror...) dans les vues" do
    offenders = Dir[Rails.root.join("app/views/**/*.erb")].select { |file| File.read(file).match?(/\son(click|error|load|change|submit|input)=/) }
    expect(offenders).to be_empty
  end
end

RSpec.describe "Rapports de violation CSP", type: :request do
  it "sont logués et acceptés sans authentification" do
    report = { "csp-report" => { "violated-directive" => "script-src", "blocked-uri" => "https://evil.example/x.js", "document-uri" => "https://www.capsule.click/" } }
    expect(Rails.logger).to receive(:warn).with(a_string_including("[CSP] script-src", "evil.example"))
    post "/csp-violations", params: report.to_json, headers: { "CONTENT_TYPE" => "application/csp-report" }
    expect(response).to have_http_status(204)
  end

  it "un corps invalide ne fait pas planter l'endpoint" do
    post "/csp-violations", params: "pas du json", headers: { "CONTENT_TYPE" => "application/csp-report" }
    expect(response).to have_http_status(204)
  end
end

RSpec.describe "Script Lottie", type: :request do
  it "est chargé dans une version figée, avec son empreinte SRI" do
    user = create(:user)
    sign_in user
    collection = Collection.create!(title: "Vide", category: "books").tap { |c| UserCollection.create!(user: user, collection: c, role: "owner") }
    get collection_path(collection)
    script = Nokogiri::HTML(response.body).at_css("script[src*='lottie-player']")
    expect(script["src"]).to include("@2.0.12")
    expect(script["integrity"]).to start_with("sha384-")
    expect(script["crossorigin"]).to eq("anonymous")
  end
end
