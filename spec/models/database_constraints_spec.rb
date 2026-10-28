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

  it "le rôle d'un utilisateur est forcément admin, premium ou free" do
    expect { user.update_columns(role: "Premium") }.to raise_error(ActiveRecord::StatementInvalid, /users_role_valid/)
  end

  it "un utilisateur a forcément un rôle" do
    expect { user.update_columns(role: nil) }.to raise_error(ActiveRecord::NotNullViolation)
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

  describe "catalogue" do
    let(:product) { create(:product) }
    let(:box) { create(:barcode_product) }

    it "une œuvre a forcément un type connu" do
      expect { product.update_columns(kind: "music") }.to raise_error(ActiveRecord::StatementInvalid, /products_kind_valid/)
    end

    it "une œuvre a forcément un titre" do
      expect { product.update_columns(title: nil) }.to raise_error(ActiveRecord::NotNullViolation)
    end

    it "un code-barres est toujours enregistré sur 13 chiffres" do
      # En SQL brut : Rails normalise le code-barres même dans update_columns et update_all
      expect { BarcodeProduct.connection.execute("UPDATE barcode_products SET barcode = '045496464851' WHERE id = #{box.id}") }
        .to raise_error(ActiveRecord::StatementInvalid, /barcode_products_barcode_valid/)
    end

    it "une boîte a forcément un type connu" do
      expect { box.update_columns(kind: "music") }.to raise_error(ActiveRecord::StatementInvalid, /barcode_products_kind_valid/)
    end

    it "une boîte vient forcément d'une source connue" do
      expect { box.update_columns(source: "amazon") }.to raise_error(ActiveRecord::StatementInvalid, /barcode_products_source_valid/)
    end

    it "une œuvre supprimée en SQL est retirée des boîtes et des items, qui restent" do
      box.update_columns(product_id: product.id)
      item = create(:item, product: product)
      Product.where(id: product.id).delete_all # sans callbacks Rails
      expect(box.reload.product_id).to be_nil
      expect(item.reload.product_id).to be_nil
    end

    it "un compte supprimé en SQL est retiré des boîtes qu'il a validées" do
      box.update_columns(confirmed_by_id: user.id)
      User.where(id: user.id).delete_all
      expect(box.reload.confirmed_by_id).to be_nil
    end
  end
end
