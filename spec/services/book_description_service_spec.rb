require "rails_helper"

RSpec.describe BookDescriptionService do
  describe ".generate" do
    context "avec titre et auteur" do
      it "retourne une description non vide" do
        allow(HTTP).to receive(:post).and_return(
          double(body: double(to_s: '{"content": [{"text": "Un livre magique sur la sorcellerie."}]}'))
        )

        result = BookDescriptionService.generate(title: "L'Atelier des Sorciers", author: "Kamome Shirahama")
        expect(result).to eq("Un livre magique sur la sorcellerie.")
      end
    end

    context "avec titre seulement" do
      it "retourne une description" do
        allow(HTTP).to receive(:post).and_return(
          double(body: double(to_s: '{"content": [{"text": "Une description générée."}]}'))
        )

        result = BookDescriptionService.generate(title: "L'Atelier des Sorciers")
        expect(result).to be_present
      end
    end

    context "quand l'API échoue" do
      it "retourne nil" do
        allow(HTTP).to receive(:post).and_raise(StandardError)

        result = BookDescriptionService.generate(title: "L'Atelier des Sorciers")
        expect(result).to be_nil
      end
    end
  end
end
