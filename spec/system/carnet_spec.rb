require "rails_helper"

RSpec.describe "Mon Carnet", type: :system do
  let(:user) { create(:user) }
  before { sign_in user }

  it "depuis l'onglet : ajouter un événement, le retrouver en prochaine sortie, avec ses souhaits à côté" do
    games = create(:collection, title: "Mes jeux", category: "video_games")
    create(:user_collection, user: user, collection: games)
    create(:wish, collection: games, title: "Ōkami", max_price: 20)

    visit collections_path
    click_on "Mon Carnet"
    expect(page).to have_content("Ce que je cherche")
    expect(page).to have_content("Ōkami")

    click_on "Événement"
    fill_in "Titre", with: "Vide-grenier de Montreuil"
    fill_in "Date", with: Date.current + 5
    fill_in "Adresse ou ville", with: "Place de la mairie"
    find("input[role='switch'][name='event[reminder]']").click
    click_on "Enregistrer"

    expect(page).to have_content("Vide-grenier de Montreuil")
    expect(user.events.last).to have_attributes(title: "Vide-grenier de Montreuil", reminder: true)

    click_on "Mon Carnet", match: :first
    expect(page).to have_content(/prochaine sortie · dans 5 jours/i) # en majuscules par le CSS
  end
end
