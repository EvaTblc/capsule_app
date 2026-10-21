require "rails_helper"

RSpec.describe "API de recherche", type: :request do
  before { sign_in create(:user) }

  let(:controller_class) { Api::SearchController }
  def json = JSON.parse(response.body)

  # Les API externes sont simulées : client HTTP factice qui enregistre les appels
  let(:http_client) { double("http client") }
  let(:http_calls) { [] }

  def fake_response(status, body)
    HTTP::Response.new(status: status, body: body.to_json, version: "1.1",
                       request: HTTP::Request.new(verb: :get, uri: "https://example.com"))
  end

  def stub_http(&responder)
    allow(HTTP).to receive(:timeout).with(10).and_return(http_client)
    allow(http_client).to receive(:headers) { |headers| http_calls << { headers: headers }; http_client }
    allow(http_client).to receive(:get) { |url, params:| http_calls << { url: url, params: params }; responder.call(url, params) }
  end

  describe "recherches texte (livres, films, musique)" do
    %w[book movie music].each do |kind|
      it "#{kind} sans query : [] sans appel externe" do
        expect(HTTP).not_to receive(:timeout)
        get "/api/search/#{kind}"
        expect(json).to eq([])
      end
    end

    it "movie : paramètres encodés par la librairie, même JSON qu'avant" do
      stub_http { fake_response(200, { results: [ { id: 1, title: "Le Fabuleux Destin", release_date: "2001-04-25", overview: "..." } ] }) }
      get "/api/search/movie", params: { query: "amélie & co" }
      expect(http_calls.last[:url]).to eq("https://api.themoviedb.org/3/search/movie")
      expect(http_calls.last[:params]).to include(query: "amélie & co", language: "fr-FR")
      expect(json).to eq([ { "id" => 1, "title" => "Le Fabuleux Destin", "year" => "2001", "description" => "..." } ])
    end

    it "music : envoie le User-Agent exigé par Discogs" do
      stub_http { fake_response(200, { results: [] }) }
      get "/api/search/music", params: { query: "daft punk" }
      expect(http_calls.first[:headers]).to eq("User-Agent" => "CapsuleApp/1.0")
    end

    it "id non numérique : 400 sans appel externe" do
      expect(HTTP).not_to receive(:timeout)
      get "/api/search/music_detail/abc"
      expect(response).to have_http_status(400)
    end
  end

  describe "erreurs des API externes" do
    it "API en erreur : 502 avec un message générique, rien ne fuite" do
      stub_http { fake_response(401, { status_message: "Invalid API key: SECRET123" }) }
      get "/api/search/movie", params: { query: "x" }
      expect(response).to have_http_status(502)
      expect(json).to eq("error" => "Recherche indisponible")
    end

    it "API trop lente : 502 au lieu d'attendre indéfiniment" do
      stub_http { raise HTTP::TimeoutError, "Read timed out" }
      get "/api/search/book", params: { query: "dune" }
      expect(response).to have_http_status(502)
    end

    it "bug interne : 500 générique" do
      allow_any_instance_of(controller_class).to receive(:upc_product_title).and_raise(RuntimeError, "secret interne")
      get "/api/search/game_barcode", params: { ean: "123" }
      expect(response).to have_http_status(500)
      expect(response.body).not_to include("secret")
    end
  end

  describe "GET /api/search/game_barcode" do
    let(:game) do
      { "id" => 1, "name" => "Zelda", "summary" => "A game", "cover" => { "url" => "//img/t_thumb/x.jpg" },
        "platforms" => [ { "name" => "Switch" } ], "genres" => [ { "name" => "RPG" } ], "first_release_date" => 1488499200 }
    end

    it "code-barres inconnu : 404 avec fallback" do
      allow_any_instance_of(controller_class).to receive(:upc_product_title).and_return(nil)
      get "/api/search/game_barcode", params: { ean: "123" }
      expect(response).to have_http_status(404)
      expect(json["fallback"]).to be true
    end

    it "jeu absent d'IGDB : 404 (et non plus un crash)" do
      allow_any_instance_of(controller_class).to receive(:upc_product_title).and_return("Zelda")
      allow_any_instance_of(controller_class).to receive(:igdb_search).and_return([])
      get "/api/search/game_barcode", params: { ean: "123" }
      expect(response).to have_http_status(404)
    end

    it "IGDB indisponible : 503" do
      allow_any_instance_of(controller_class).to receive(:upc_product_title).and_return("Zelda")
      allow_any_instance_of(controller_class).to receive(:igdb_search).and_return(nil)
      get "/api/search/game_barcode", params: { ean: "123" }
      expect(response).to have_http_status(503)
    end

    it "jeu trouvé : titre nettoyé, résumé traduit, même JSON qu'avant" do
      allow_any_instance_of(controller_class).to receive(:upc_product_title).and_return("Zelda - Nintendo Switch")
      expect_any_instance_of(controller_class).to receive(:igdb_search).with("Zelda", limit: 1).and_return([ game ])
      allow(TranslationService).to receive(:translate_batch).and_return([ "Un jeu" ])
      get "/api/search/game_barcode", params: { ean: "123" }
      expect(json).to include("name" => "Zelda", "summary" => "Un jeu", "platforms" => "Switch",
                              "release_date" => 2017, "cover_url" => "https://img/t_cover_big/x.jpg")
      expect(json["metadata"]).to include("release_date" => "2017-03-03", "genres" => "RPG")
    end
  end

  describe "GET /api/search/movie_barcode" do
    it "code-barres inconnu : 404 directement, sans appels inutiles à OMDb / TMDB" do
      allow_any_instance_of(controller_class).to receive(:upc_product_title).and_return(nil)
      expect(HTTP).not_to receive(:timeout)
      get "/api/search/movie_barcode", params: { ean: "123" }
      expect(response).to have_http_status(404)
    end

    it "film trouvé : titre nettoyé puis détails et réalisateur" do
      allow_any_instance_of(controller_class).to receive(:upc_product_title).and_return("Inception (DVD)")
      stub_http do |url, params|
        case url
        when %r{search/movie}
          expect(params[:query]).to eq("Inception")
          fake_response(200, { results: [ { id: 27205, title: "Inception", release_date: "2010-07-16" } ] })
        when /credits/ then fake_response(200, { crew: [ { job: "Director", name: "Christopher Nolan" } ] })
        else fake_response(200, { production_companies: [ { name: "Warner" } ] })
        end
      end
      get "/api/search/movie_barcode", params: { ean: "123" }
      expect(json).to include("title" => "Inception", "year" => 2010, "director" => "Christopher Nolan", "studio" => "Warner")
    end
  end

  describe "GET /api/search/search_game" do
    it "retire les guillemets de la requête IGDB et oublie un token expiré" do
      allow(IgdbService).to receive(:access_token).and_return("tok")
      expect(HTTParty).to receive(:post) { |_, options|
        expect(options[:body]).to include('search "Zelda trick; fields *"')
        double(code: 401)
      }
      expect(Rails.cache).to receive(:delete).with(IgdbService::CACHE_KEY)
      get "/api/search/search_game", params: { query: 'Zelda" trick; fields *' }
      expect(response).to have_http_status(503)
    end
  end

  describe "nettoyage des titres de films" do
    {
      "Spider-Man: No Way Home DVD" => "Spider-Man: No Way Home",
      "Inception - Blu-ray" => "Inception",
      "Inception (DVD)" => "Inception",
      "Warner - Inception DVD" => "Inception",
      "X-Men [Import]" => "X-Men"
    }.each do |raw, clean|
      it("#{raw} → #{clean}") { expect(controller_class.new.send(:clean_movie_title, raw)).to eq(clean) }
    end
  end
end
