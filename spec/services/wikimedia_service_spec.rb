require "rails_helper"

# Réponses de Wikidata et Wikipédia simulées, reprises (en abrégé) des vraies réponses pour Inception
RSpec.describe WikimediaService do
  let(:http) { double("http client") }

  def fake_response(status, body)
    HTTP::Response.new(status: status, body: body.to_json, version: "1.1",
                       request: HTTP::Request.new(verb: :get, uri: "https://example.com"))
  end

  def date_claim(time, country = nil)
    claim = { "mainsnak" => { "datavalue" => { "value" => { "time" => time } } } }
    claim["qualifiers"] = { "P291" => [ { "datavalue" => { "value" => { "id" => country } } } ] } if country
    claim
  end

  def item_claim(id) = { "mainsnak" => { "datavalue" => { "value" => { "id" => id } } } }

  let(:inception) do
    { "labels" => { "fr" => { "value" => "Inception" } },
      "sitelinks" => { "frwiki" => { "title" => "Inception" } },
      "claims" => {
        "P1476" => [ { "mainsnak" => { "datavalue" => { "value" => { "text" => "Inception" } } } } ],
        "P577" => [ date_claim("+2010-07-08T00:00:00Z", "Q84"), date_claim("+2010-07-21T00:00:00Z", "Q142") ],
        "P57" => [ item_claim("Q25191") ],
        "P272" => [ item_claim("Q984047") ]
      } }
  end

  before do
    allow(HTTP).to receive(:timeout).with(10).and_return(http)
    allow(http).to receive(:headers).with(WikimediaService::HEADERS).and_return(http)
  end

  describe ".movie" do
    def wikidata_returns(search:, entity: inception)
      allow(http).to receive(:get) do |_url, params:|
        case params[:action]
        when "query" then fake_response(200, { "query" => { "search" => search } })
        when "wbgetentities"
          if params[:props] == "labels"
            fake_response(200, { "entities" => { "Q25191" => { "labels" => { "fr" => { "value" => "Christopher Nolan" } } },
                                                 "Q984047" => { "labels" => { "en" => { "value" => "Syncopy Films" } } } } })
          else
            fake_response(200, { "entities" => { "Q25188" => entity } })
          end
        end
      end
    end

    it "trouve le film par son identifiant TMDB (P4947) et lit sa fiche" do
      wikidata_returns(search: [ { "title" => "Q25188" } ])
      expect(described_class.movie(27205)).to eq(
        wikidata_id: "Q25188", title: "Inception", original_title: "Inception",
        release_year: 2010, directors: [ "Christopher Nolan" ], studios: [ "Syncopy Films" ], wikipedia_title: "Inception"
      )
    end

    it "année de sortie en France plutôt que la plus ancienne" do
      entity = inception.deep_merge("claims" => { "P577" => [ date_claim("+2011-11-02T00:00:00Z", "Q142"), date_claim("+2010-09-11T00:00:00Z", "Q16") ] })
      wikidata_returns(search: [ { "title" => "Q25188" } ], entity: entity)
      expect(described_class.movie(27205)[:release_year]).to eq(2011)
    end

    it "erreur passagère de la recherche : un second essai" do
      wikidata_returns(search: [ { "title" => "Q25188" } ])
      calls = 0
      allow(http).to receive(:get).with(WikimediaService::WIKIDATA_API, params: hash_including(action: "query")) do
        calls += 1
        fake_response(200, calls == 1 ? { "error" => { "code" => "internal_api_error" } } : { "query" => { "search" => [ { "title" => "Q25188" } ] } })
      end
      expect(described_class.movie(27205)).to include(title: "Inception")
      expect(calls).to eq(2)
    end

    it "film inconnu de Wikidata, ou Wikidata injoignable : nil" do
      wikidata_returns(search: [])
      expect(described_class.movie(27205)).to be_nil

      allow(http).to receive(:get).and_raise(HTTP::TimeoutError)
      expect(described_class.movie(27205)).to be_nil
    end
  end

  describe ".book_work_id et .book : l'œuvre d'un livre" do
    def entity(label, instance_of:, authors: [ "Q34660" ])
      { "labels" => { "fr" => { "value" => label } },
        "claims" => { "P31" => [ item_claim(instance_of) ], "P50" => authors.map { |id| item_claim(id) } } }
    end

    def wikidata_returns(search_ids, entities)
      allow(http).to receive(:get) do |_url, params:|
        if params[:action] == "query"
          fake_response(200, { "query" => { "search" => search_ids.map { |id| { "title" => id } } } })
        elsif params[:props] == "labels"
          fake_response(200, { "entities" => { "Q34660" => { "labels" => { "fr" => { "value" => "J. K. Rowling" } } } } })
        else
          fake_response(200, { "entities" => entities.slice(*params[:ids].split("|")) })
        end
      end
    end

    it "écarte l'édition trouvée en premier et garde l'œuvre (même titre, auteur du même nom)" do
      wikidata_returns(%w[Q58464836 Q43361],
                       "Q58464836" => entity("Harry Potter à l'école des sorciers", instance_of: "Q3331189"), # une édition
                       "Q43361" => entity("Harry Potter à l'école des sorciers", instance_of: "Q7725634"))
      expect(described_class.book_work_id(title: "Harry Potter à l'école des sorciers", author: "J.K. Rowling")).to eq("Q43361")
    end

    it "écarte une série entière (sinon chaque tome serait relié à la série)" do
      wikidata_returns(%w[Q28667972], "Q28667972" => entity("One Piece", instance_of: "Q21198342"))
      expect(described_class.book_work_id(title: "One Piece", author: "Eiichiro Oda")).to be_nil
    end

    it "titre différent ou auteur différent : pas de correspondance" do
      wikidata_returns(%w[Q1], "Q1" => entity("Harry Potter et la Chambre des secrets", instance_of: "Q7725634"))
      expect(described_class.book_work_id(title: "Harry Potter à l'école des sorciers", author: "J.K. Rowling")).to be_nil
      wikidata_returns(%w[Q2], "Q2" => entity("Harry Potter à l'école des sorciers", instance_of: "Q7725634"))
      expect(described_class.book_work_id(title: "Harry Potter à l'école des sorciers", author: "Jean Dupont")).to be_nil
    end

    it ".book refuse un identifiant mal formé, une œuvre sans auteur ou une série" do
      expect(http).not_to receive(:get)
      expect(described_class.book("Q1|Q2")).to be_nil
      expect(described_class.book("abc")).to be_nil
    end
  end

  describe ".summary" do
    it "introduction de l'article en français, et son adresse" do
      expect(http).to receive(:get).with("#{WikimediaService::WIKIPEDIA_SUMMARY}Intouchables_%28film%29", params: {}) # titre encodé dans l'adresse
        .and_return(fake_response(200, { "type" => "standard", "extract" => "Intouchables est une comédie dramatique…",
                                         "content_urls" => { "desktop" => { "page" => "https://fr.wikipedia.org/wiki/Intouchables_(film)" } } }))
      expect(described_class.summary("Intouchables (film)")).to eq(text: "Intouchables est une comédie dramatique…",
                                                                   url: "https://fr.wikipedia.org/wiki/Intouchables_(film)")
    end

    it "page d'homonymie, article absent ou pas de titre : nil" do
      allow(http).to receive(:get).and_return(fake_response(200, { "type" => "disambiguation", "extract" => "Intouchable peut désigner…" }))
      expect(described_class.summary("Intouchables")).to be_nil
      allow(http).to receive(:get).and_return(fake_response(404, {}))
      expect(described_class.summary("Inexistant")).to be_nil
      expect(described_class.summary(nil)).to be_nil
    end
  end
end
