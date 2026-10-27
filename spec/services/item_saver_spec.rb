require "rails_helper"

RSpec.describe ItemSaver do
  include ActiveJob::TestHelper

  let(:collection) { create(:collection, category: "video_games") }

  let(:premium) { create(:user, :premium) }

  def save(item, type:, detail: {}, item_attributes: {}, images: nil, user: premium)
    described_class.new(item, user: user, item_attributes: { title: "Zelda" }.merge(item_attributes),
                              detail_type: type, detail_attributes: detail, images: images).save
  end

  describe "liste blanche des types" do
    it "refuse un type inconnu (pas de constantize arbitraire)" do
      expect { described_class.detail_class("User") }.to raise_error(ItemSaver::UnknownDetailType)
    end

    it "n'accepte pas les colonnes techniques d'un détail" do
      expect(described_class.permitted_detail_columns("BookDetail")).not_to include("id", "created_at", "updated_at")
    end
  end

  describe "création" do
    let(:item) { collection.items.new }

    it "crée l'item et son détail ensemble" do
      expect(save(item, type: "BookDetail", detail: { "author" => "Herbert", "description" => "x" })).to be true
      expect(item.reload.item_detailable).to have_attributes(author: "Herbert")
    end

    it "jeu : le résumé du formulaire part dans summary_en, et la traduction est mise en file" do
      expect { save(item, type: "VideoGameDetail", detail: { "description" => "An epic game" }) }.to have_enqueued_job(TranslationJob)
      expect(item.item_detailable).to have_attributes(summary_en: "An epic game", description: nil)
    end

    it "jeu par l'ajout rapide : le summary_en envoyé directement est conservé" do
      save(item, type: "VideoGameDetail", detail: { "summary_en" => "An epic game" })
      expect(item.item_detailable.summary_en).to eq("An epic game")
    end

    it "livre sans description : résumé généré en arrière-plan" do
      expect { save(item, type: "BookDetail", detail: { "author" => "Herbert" }) }.to have_enqueued_job(BookDescriptionJob)
    end

    it "échec : rien n'est créé, les erreurs de l'item et du détail sont réunies" do
      expect {
        expect(save(item, type: "FigurineDetail", detail: { "edition" => "Bidon" }, item_attributes: { title: "" })).to be false
      }.not_to change(FigurineDetail, :count)
      expect(item.errors.full_messages).to include(a_string_including("titre"), a_string_including("Edition"))
    end
  end

  describe "compte free : aucun appel payant" do
    let(:item) { collection.items.new }
    let(:free) { create(:user) }

    it "jeu : pas de traduction, le résumé anglais est gardé" do
      expect { save(item, type: "VideoGameDetail", detail: { "description" => "An epic game" }, user: free) }
        .not_to have_enqueued_job(TranslationJob)
      expect(item.item_detailable.summary_en).to eq("An epic game")
    end

    it "livre sans description : pas de résumé généré, mais l'item est bien créé" do
      expect { save(item, type: "BookDetail", detail: { "author" => "Herbert" }, user: free) }
        .not_to have_enqueued_job(BookDescriptionJob)
      expect(item).to be_persisted
    end

    it "admin : les tâches payantes sont lancées" do
      expect { save(item, type: "VideoGameDetail", detail: { "description" => "An epic game" }, user: create(:user, :admin)) }
        .to have_enqueued_job(TranslationJob)
    end
  end

  describe "modification" do
    let(:detail) { create(:video_game_detail, summary_en: "An epic game", description: "Un jeu épique") }
    let(:item) { create(:item, collection: collection, item_detailable: detail, item_detailable_type: "VideoGameDetail") }

    it "ne retraduit pas quand la description n'a pas changé" do
      expect { save(item, type: "VideoGameDetail", detail: { "description" => "Un jeu épique", "platform" => "Switch" }) }
        .not_to have_enqueued_job(TranslationJob)
      expect(detail.reload).to have_attributes(platform: "Switch", description: "Un jeu épique")
    end

    it "retraduit quand la description change (autre jeu choisi via la recherche)" do
      expect { save(item, type: "VideoGameDetail", detail: { "description" => "Another game" }) }.to have_enqueued_job(TranslationJob)
      expect(detail.reload).to have_attributes(summary_en: "Another game", description: nil)
    end

    it "changement de type : nouveau détail, l'ancien n'est supprimé qu'après le succès" do
      save(item, type: "BookDetail", detail: { "author" => "Herbert", "description" => "x" })
      expect(item.reload.item_detailable).to be_a(BookDetail)
      expect(VideoGameDetail.exists?(detail.id)).to be false
    end

    it "changement de type invalide : l'ancien détail est intact" do
      expect(save(item, type: "FigurineDetail", detail: { "edition" => "Bidon" })).to be false
      expect(item.reload.item_detailable).to eq(detail)
    end

    it "les nouvelles photos s'ajoutent aux existantes" do
      item.images.attach(io: StringIO.new("a"), filename: "a.jpg", content_type: "image/jpeg")
      photo = Rack::Test::UploadedFile.new(StringIO.new("b"), "image/jpeg", original_filename: "b.jpg")
      save(item, type: "VideoGameDetail", images: [ photo ])
      expect(item.reload.images.count).to eq(2)
    end
  end
end
