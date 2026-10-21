require "rails_helper"

RSpec.describe AnthropicClient do
  let(:messages) { double("messages") }
  before { allow(AnthropicClient).to receive(:sdk).and_return(double(messages: messages)) }

  def reply(*blocks, stop_reason: :end_turn, stop_details: nil)
    double(content: blocks, stop_reason: stop_reason, stop_details: stop_details)
  end

  def text_block(text) = double(type: :text, text: text)
  def thinking_block = double(type: :thinking)

  describe ".sdk" do
    it "configure le SDK avec un timeout court et 2 retries" do
      allow(AnthropicClient).to receive(:sdk).and_call_original
      AnthropicClient.instance_variable_set(:@sdk, nil)
      expect(Anthropic::Client).to receive(:new).with(hash_including(timeout: 60, max_retries: 2)).and_call_original
      AnthropicClient.sdk
    ensure
      AnthropicClient.instance_variable_set(:@sdk, nil)
    end
  end

  describe ".text" do
    it "envoie le modèle Haiku 5.5 avec un effort bas et renvoie le texte" do
      expect(messages).to receive(:create).with(hash_including(
        model: "claude-haiku-5-5",
        max_tokens: 2048,
        output_config: { effort: :low },
        messages: [ { role: "user", content: "Bonjour" } ]
      )).and_return(reply(text_block("Salut ")))

      expect(AnthropicClient.text("Bonjour")).to eq("Salut")
    end

    it "ignore les blocs de réflexion en tête de réponse" do
      allow(messages).to receive(:create).and_return(reply(thinking_block, text_block("Réponse")))
      expect(AnthropicClient.text("x")).to eq("Réponse")
    end

    it "transforme un refus en AnthropicClient::Error avec sa catégorie" do
      allow(messages).to receive(:create).and_return(reply(stop_reason: :refusal, stop_details: double(category: :cyber)))
      expect { AnthropicClient.text("x") }.to raise_error(AnthropicClient::Error, /refusée.*cyber/)
    end

    it "transforme une réponse tronquée en AnthropicClient::Error" do
      allow(messages).to receive(:create).and_return(reply(thinking_block, stop_reason: :max_tokens))
      expect { AnthropicClient.text("x") }.to raise_error(AnthropicClient::Error, /tronquée/)
    end

    it "transforme une erreur du SDK en AnthropicClient::Error" do
      allow(messages).to receive(:create).and_raise(Anthropic::Errors::Error, "overloaded")
      expect { AnthropicClient.text("x") }.to raise_error(AnthropicClient::Error, /overloaded/)
    end
  end

  describe ".json" do
    it "retire les balises ```json" do
      allow(messages).to receive(:create).and_return(reply(text_block("```json\n{\"a\": 1}\n```")))
      expect(AnthropicClient.json("x")).to eq("a" => 1)
    end

    it "lève AnthropicClient::Error si la réponse n'est pas du JSON" do
      allow(messages).to receive(:create).and_return(reply(text_block("Désolé, je ne peux pas")))
      expect { AnthropicClient.json("x") }.to raise_error(AnthropicClient::Error, /non JSON/)
    end
  end

  describe "services qui l'utilisent" do
    it "TranslationService garde les paragraphes et demande assez de tokens" do
      expect(messages).to receive(:create).with(hash_including(max_tokens: 8192))
        .and_return(reply(text_block([ "Paragraphe un.\n\nParagraphe deux." ].to_json)))
      expect(TranslationService.translate_batch([ "Para one.\n\nPara two." ])).to eq([ "Paragraphe un.\n\nParagraphe deux." ])
    end

    it "TranslationService lève TranslationService::Error en cas d'échec (pour que le job réessaie)" do
      allow(messages).to receive(:create).and_raise(Anthropic::Errors::Error, "boom")
      expect { TranslationService.translate_batch([ "Hello" ]) }.to raise_error(TranslationService::Error)
    end

    it "TranslationService refuse une réponse avec le mauvais nombre de traductions" do
      allow(messages).to receive(:create).and_return(reply(text_block('["un", "deux"]')))
      expect { TranslationService.translate_batch([ "one" ]) }.to raise_error(TranslationService::Error, /inattendue/)
    end

    it "FigurineIdentificationService envoie l'image" do
      expect(messages).to receive(:create) { |args|
        expect(args[:messages][0][:content][0]).to include(type: "image")
        reply(text_block('{"name": "Goku"}'))
      }
      expect(FigurineIdentificationService.identify("BASE64")).to eq("name" => "Goku")
    end
  end
end
