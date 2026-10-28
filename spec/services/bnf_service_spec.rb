require "rails_helper"

# Les réponses de la BnF sont de vraies notices enregistrées (spec/fixtures/files/bnf) : aucun appel réseau
RSpec.describe BnfService do
  let(:http) { double("http client") }

  def fake_response(status, body)
    HTTP::Response.new(status: status, body: body, version: "1.1",
                       request: HTTP::Request.new(verb: :get, uri: "https://example.com"))
  end

  def bnf_returns(fixture)
    allow(http).to receive(:get).and_return(fake_response(200, file_fixture("bnf/#{fixture}.xml").read))
  end

  before { allow(HTTP).to receive(:timeout).with(10).and_return(http) }

  describe "lecture de la notice" do
    it "jeu : titre, complément, support, éditeur français, année et développeur" do
      bnf_returns("pokemon_diamant")
      expect(described_class.find_by_ean("0045496464851")).to eq(
        kind: "game", # notice de type « ressource électronique »
        bnf_ark: "ark:/12148/cb41198117k",
        title: "Pokémon",
        complement: "version diamant",
        support: "1 cartouche Nintendo DS",
        publisher: "Nintendo France", # le distributeur, sans « [distrib.] »
        release_year: 2007,           # extrait de « cop. 2007 »
        creators: { "635" => [ "Game freak" ] }
      )
    end

    it "film : édition, format, éditeur sans « [éd., distrib.] », et chaque contributeur sous chacun de ses rôles" do
      bnf_returns("inception_bluray")
      result = described_class.find_by_ean("5051889041535")
      expect(result).to include(kind: "movie", title: "Inception", complement: "ultimate edition", support: "2 BD vidéo (2 h 22 min)",
                                publisher: "Warner home video", release_year: 2010)
      expect(result[:creators]).to include("300" => [ "Christopher Nolan" ], "690" => [ "Christopher Nolan" ],
                                           "230" => [ "Hans Zimmer" ])
      expect(result[:creators]["005"]).to include("Leonardo DiCaprio")
    end

    it "livre récent : éditeur et année en zone 214 (et non 210), auteur" do
      bnf_returns("veiller_sur_elle")
      expect(described_class.find_by_ean("9782378803759")).to include(
        kind: "book", title: "Veiller sur elle", publisher: "l'Iconoclaste", release_year: 2023,
        support: "1 vol. (580 p.)", creators: { "070" => [ "Jean-Baptiste Andrea" ] }
      )
    end
  end

  it "notice ancienne à l'en-tête incomplet (L'Étranger, Folio 1971) : reconnue comme livre" do
    bnf_returns("etranger_ancien")
    expect(described_class.find_by_ean("9782070360024")).to include(kind: "book", title: "L'Étranger", publisher: "Gallimard",
                                                                     creators: hash_including("070" => [ "Albert Camus" ]))
  end

  describe "requête" do
    it "cherche le code sous ses deux formes (12 et 13 chiffres), en EAN et en ISBN" do
      expect(http).to receive(:get)
        .with(BnfService::URL, params: hash_including(query: 'bib.ean any "045496464851 0045496464851" or bib.isbn any "045496464851 0045496464851"'))
        .and_return(fake_response(200, file_fixture("bnf/pokemon_diamant.xml").read))
      described_class.find_by_ean("045496464851")
    end

    it "livre : cherche aussi l'ISBN à 10 chiffres (livres anciens catalogués avant 2007), clé « X » comprise" do
      expect(http).to receive(:get)
        .with(BnfService::URL, params: hash_including(query: 'bib.ean any "9782070360024 2070360024" or bib.isbn any "9782070360024 2070360024"'))
        .and_return(fake_response(200, file_fixture("bnf/veiller_sur_elle.xml").read))
      described_class.find_by_ean("9782070360024")
      expect(described_class.send(:isbn10, "9781000000010")).to eq("100000001X")
    end

    it "accepte un code passé en nombre" do
      bnf_returns("pokemon_diamant")
      expect(described_class.find_by_ean(45496464851)).to include(title: "Pokémon")
    end

    it "code qui n'est pas une suite de chiffres : nil, sans appel à la BnF" do
      expect(HTTP).not_to receive(:timeout)
      [ "../x", "123?x=1", "1234", "", nil ].each { |code| expect(described_class.find_by_ean(code)).to be_nil }
    end
  end

  describe "rien d'exploitable : nil, pour que la recherche passe au service suivant" do
    it "code inconnu de la BnF" do
      empty = '<srw:searchRetrieveResponse xmlns:srw="http://www.loc.gov/zing/srw/"><srw:numberOfRecords>0</srw:numberOfRecords></srw:searchRetrieveResponse>'
      allow(http).to receive(:get).and_return(fake_response(200, empty))
      expect(described_class.find_by_ean("9999999999994")).to be_nil
    end

    it "BnF en erreur" do
      allow(http).to receive(:get).and_return(fake_response(503, "Service Unavailable"))
      expect(described_class.find_by_ean("0045496464851")).to be_nil
    end

    it "BnF injoignable ou trop lente" do
      allow(http).to receive(:get).and_raise(HTTP::TimeoutError)
      expect(described_class.find_by_ean("0045496464851")).to be_nil
    end

    it "réponse illisible" do
      allow(http).to receive(:get).and_return(fake_response(200, "<html>maintenance</html>"))
      expect(described_class.find_by_ean("0045496464851")).to be_nil
    end
  end
end
