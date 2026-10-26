require "rails_helper"

RSpec.describe "Identification de figurine", type: :request do
  before { sign_in create(:user) }

  # Débuts de fichiers réels (signatures binaires) : seul le format compte pour ces tests
  let(:jpeg) { "\xFF\xD8\xFF\xE0".b + "x" * 100 }
  let(:png)  { "\x89PNG\r\n\x1A\n".b + "x" * 100 }
  let(:heic) { "\x00\x00\x00\x18ftypheic".b + "x" * 100 }

  def identify(bytes) = post("/items/identify", params: { image: Base64.strict_encode64(bytes) }, as: :json)
  def json = JSON.parse(response.body)

  it "photo reconnue : renvoie les champs" do
    allow(FigurineIdentificationService).to receive(:identify).and_return("name" => "Goku", "series" => "Dragon Ball")
    identify(jpeg)
    expect(response).to have_http_status(200)
    expect(json).to include("name" => "Goku")
  end

  it "envoie à Claude le vrai format de l'image (et non plus toujours image/jpeg)" do
    expect(FigurineIdentificationService).to receive(:identify).with(anything, media_type: "image/png").and_return("name" => "Goku")
    identify(png)
  end

  it "format non pris en charge (HEIC) : message clair, pas d'appel payant" do
    expect(FigurineIdentificationService).not_to receive(:identify)
    identify(heic)
    expect(response).to have_http_status(422)
    expect(json["error"]).to include("Format de photo non pris en charge")
  end

  it "photo trop lourde : refusée avant l'appel à Claude" do
    expect(FigurineIdentificationService).not_to receive(:identify)
    identify(jpeg + "x" * 5.megabytes)
    expect(response).to have_http_status(413)
  end

  it "contenu illisible (pas du base64) : 422" do
    post "/items/identify", params: { image: "pas du base64 !!" }, as: :json
    expect(response).to have_http_status(422)
  end

  it "figurine non reconnue (tous les champs à null) : message au lieu d'un formulaire vide" do
    allow(FigurineIdentificationService).to receive(:identify).and_return("title" => nil, "name" => nil, "series" => nil)
    identify(jpeg)
    expect(response).to have_http_status(422)
    expect(json["error"]).to include("non reconnue")
  end

  it "échec de l'appel à Claude : message au lieu d'un formulaire vide" do
    allow(FigurineIdentificationService).to receive(:identify).and_return({})
    identify(jpeg)
    expect(json["error"]).to include("non reconnue")
  end
end

RSpec.describe FigurineIdentificationService, ".media_type_of" do
  {
    "\xFF\xD8\xFF\xE0".b => "image/jpeg",
    "\x89PNG\r\n\x1A\n".b => "image/png",
    "GIF89a".b => "image/gif",
    "RIFF\x00\x00\x00\x00WEBP".b => "image/webp",
    "\x00\x00\x00\x18ftypheic".b => nil
  }.each do |bytes, type|
    it("#{type || "HEIC"} → #{type.inspect}") { expect(described_class.media_type_of(bytes + "rest")).to eq(type) }
  end
end
