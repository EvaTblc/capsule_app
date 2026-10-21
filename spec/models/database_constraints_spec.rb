require "rails_helper"

# Ces contraintes tiennent même quand on contourne les validations Rails (update_columns, insert_all, console...)
RSpec.describe "Contraintes de la base" do
  let(:user) { create(:user) }
  let(:collection) { create(:collection) }
  let(:now) { Time.current }

  it "une seule adhésion par utilisateur et par collection" do
    UserCollection.create!(user: user, collection: collection, role: "owner")
    expect(UserCollection.new(user: user, collection: collection, role: "member")).not_to be_valid
    expect {
      UserCollection.insert_all!([ { user_id: user.id, collection_id: collection.id, role: "member", created_at: now, updated_at: now } ])
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "le rôle est forcément owner ou member" do
    membership = UserCollection.create!(user: user, collection: collection, role: "owner")
    expect { membership.update_columns(role: "Owner") }.to raise_error(ActiveRecord::StatementInvalid, /user_collections_role_valid/)
  end

  it "un seul événement par lien et par utilisateur, mais plusieurs événements sans lien" do
    create(:event, user: user, url: "https://brocabrac.fr/1")
    expect { create(:event, user: user, url: "https://brocabrac.fr/1") }.to raise_error(ActiveRecord::RecordNotUnique)
    expect { 2.times { create(:event, user: user, url: nil) } }.not_to raise_error
  end

  # Un exemple par violation : après une erreur SQL, PostgreSQL bloque le reste de la transaction du test
  it "le titre d'un item est obligatoire" do
    item = create(:item)
    expect { item.update_columns(title: nil) }.to raise_error(ActiveRecord::NotNullViolation)
  end

  it "le titre d'une collection est obligatoire" do
    expect { collection.update_columns(title: nil) }.to raise_error(ActiveRecord::NotNullViolation)
  end

  it "un jeton d'invitation ne peut pas servir deux collections" do
    other = create(:collection)
    expect { other.update_columns(invite_token: collection.invite_token) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "un expéditeur supprimé en SQL est vidé, pas laissé orphelin" do
    sender = create(:user)
    note = create(:note, user: user, sender: sender)
    User.where(id: sender.id).delete_all # sans callbacks Rails
    expect(note.reload.sender_id).to be_nil
  end
end
