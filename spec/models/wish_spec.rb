require "rails_helper"

RSpec.describe Wish, type: :model do
  describe "associations" do
    it { should belong_to(:collection) }
    it { should belong_to(:author).class_name("User").optional }
    it { should belong_to(:product).optional }
  end

  it "titre obligatoire" do
    expect(build(:wish, title: "")).not_to be_valid
  end

  describe "prix maximum" do
    it "facultatif" do
      expect(build(:wish, max_price: nil)).to be_valid
    end

    it "garde les centimes exacts (2,50 €)" do
      wish = create(:wish, max_price: "2.50")
      expect(wish.reload.max_price).to eq(BigDecimal("2.5"))
    end

    it "refuse 0 € et un prix négatif" do
      expect(build(:wish, max_price: 0)).not_to be_valid
      expect(build(:wish, max_price: -3)).not_to be_valid
    end
  end

  describe "une même œuvre, une seule fois par collection" do
    let(:collection) { create(:collection) }
    let(:product) { create(:product) }
    before { create(:wish, collection: collection, product: product) }

    it "refuse le doublon dans la même collection, avec un message (pas d'exception)" do
      duplicate = build(:wish, collection: collection, product: product)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:product_id]).to be_present
    end

    it "accepte la même œuvre dans une autre collection" do
      expect(build(:wish, product: product)).to be_valid
    end

    it "accepte plusieurs souhaits saisis à la main (sans œuvre du catalogue)" do
      create(:wish, collection: collection, product: nil)
      expect(build(:wish, collection: collection, product: nil)).to be_valid
    end

    it "l'index unique protège aussi la base, même sans passer par la validation" do
      duplicate = build(:wish, collection: collection, product: product)
      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "auteur membre de la collection" do
    it "accepte un membre" do
      expect(build(:wish, :by_member)).to be_valid
    end

    it "refuse un non-membre (collection_id forgé)" do
      wish = build(:wish, author: create(:user))
      expect(wish).not_to be_valid
      expect(wish.errors[:collection]).to be_present
    end

    it "reste modifiable si l'auteur a quitté la collection depuis" do
      wish = create(:wish, :by_member)
      UserCollection.where(user: wish.author).destroy_all
      expect(wish.update(title: "Ōkami HD")).to be(true)
    end
  end

  describe "suppressions" do
    it "supprimer la collection supprime ses souhaits" do
      wish = create(:wish)
      expect { wish.collection.destroy }.to change(Wish, :count).by(-1)
    end

    it "collection partagée : supprimer le compte de l'auteur garde le souhait (pour les autres membres), sans auteur" do
      wish = create(:wish, :by_member)
      create(:user_collection, user: create(:user), collection: wish.collection, role: "member")
      wish.author.destroy
      expect(wish.reload.author).to be_nil
    end

    it "supprimer l'œuvre du catalogue garde le souhait, sans œuvre" do
      wish = create(:wish, product: create(:product))
      wish.product.destroy
      expect(wish.reload.product_id).to be_nil
    end
  end

  it "côté utilisateur : les amis voient ses souhaits par défaut" do
    expect(User.new.wishes_visible_to_friends).to be(true)
  end
end
