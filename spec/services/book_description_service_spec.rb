require "rails_helper"

RSpec.describe BookDescriptionService do
  describe ".generate" do
    context "avec titre et auteur" do
      it "retourne une description non vide" do
        allow(AnthropicClient).to receive(:text).and_return("Un livre magique sur la sorcellerie.")

        result = BookDescriptionService.generate(title: "L'Atelier des Sorciers", author: "Kamome Shirahama")
        expect(result).to eq("Un livre magique sur la sorcellerie.")
      end
    end

    context "avec titre seulement" do
      it "retourne une description" do
        allow(AnthropicClient).to receive(:text).and_return("Une description générée.")

        result = BookDescriptionService.generate(title: "L'Atelier des Sorciers")
        expect(result).to be_present
      end
    end

    context "quand l'API échoue" do
      it "lève l'erreur pour que BookDescriptionJob puisse réessayer" do
        allow(AnthropicClient).to receive(:text).and_raise(AnthropicClient::Error, "API indisponible")

        expect {
          BookDescriptionService.generate(title: "L'Atelier des Sorciers")
        }.to raise_error(AnthropicClient::Error)
      end
    end
  end
end
