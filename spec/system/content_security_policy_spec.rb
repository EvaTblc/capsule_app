require "rails_helper"

# La CSP doit pouvoir bloquer pour de bon : aucun parcours réel ne doit déclencher de violation.
# Piège connu : Turbo garde le nonce du premier chargement ; un nonce qui change (à chaque requête, ou quand
# la session est vidée à la déconnexion) faisait bloquer les scripts en ligne des pages suivantes
RSpec.describe "Content Security Policy (navigateur)", type: :system do
  let(:reports) { [] }

  before do
    allow_any_instance_of(CspReportsController).to receive(:create).and_wrap_original do |original, *args|
      reports << original.receiver.request.raw_post
      original.call(*args)
    end
  end

  # Les rapports partent du navigateur un peu après le chargement
  def expect_no_violation
    sleep 1
    expect(reports).to be_empty, "violations CSP : #{reports.join("\n")}"
  end

  it "le dispositif fonctionne : un script interdit est bien signalé" do
    visit "/"
    page.execute_script(<<~JS)
      const script = document.createElement("script"); script.src = "https://evil.example.com/x.js"; document.head.appendChild(script)
    JS
    20.times { break if reports.any?; sleep 0.25 }
    expect(reports.first).to include("evil.example.com")
  end

  it "connexion par le formulaire, navigation via Turbo, puis déconnexion : aucune violation" do
    user = create(:user, email: "eva@example.com", password: "motdepasse1", password_confirmation: "motdepasse1")
    books = Collection.create!(title: "Livres", category: "books").tap { |c| UserCollection.create!(user: user, collection: c, role: "owner") }

    visit "/"
    click_on "Connexion"
    fill_in "user_email", with: "eva@example.com"
    fill_in "user_password", with: "motdepasse1"
    find("[type=submit]").click
    expect(page).to have_current_path("/collections")

    click_on "Livres"
    find("a[href='#{new_collection_item_path(books)}']", match: :first).click
    expect(page).to have_current_path(new_collection_item_path(books))
    visit "/profile"
    click_on "Se déconnecter"
    expect(page).to have_current_path("/")

    expect_no_violation
  end
end
