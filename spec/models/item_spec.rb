require "rails_helper"

RSpec.describe Item, type: :model do
describe "associations" do
  it { should belong_to(:collection) }

  it "est polymorphique" do
    item = create(:item)
    expect(item.item_detailable).to be_a(BookDetail)
  end
end

  describe "factory" do
    it "crée un item valide" do
      item = build(:item)
      expect(item).to be_valid
    end
  end

  describe "item_type" do
    it "correspond au type du détail" do
      book_detail = create(:book_detail)
      item = create(:item, item_detailable: book_detail, item_type: "BookDetail", item_detailable_type: "BookDetail")
      expect(item.item_type).to eq("BookDetail")
    end
  end

  describe "condition" do
    it "accepte les valeurs valides" do
      ["Neuf", "Très bon état", "Bon état", "Correct", "Mauvais état"].each do |condition|
        item = build(:item, condition: condition)
        expect(item.condition).to eq(condition)
      end
    end
  end

  describe "images" do
    it "peut exister sans image" do
      item = create(:item)
      expect(item.images.attached?).to eq(false)
    end
  end
end
