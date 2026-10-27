require "rails_helper"

RSpec.describe "API de recherche", type: :request do
  before { sign_in create(:user, :premium) }

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
      allow(BarcodeService).to receive(:product_title).and_raise(RuntimeError, "secret interne")
      get "/api/search/game_barcode", params: { ean: "123" }
      expect(response).to have_http_status(500)
      expect(response.body).not_to include("secret")
    end
  end

  describe "compte free" do
    before { sign_in create(:user) }

    it "scans de jeux et de films : 403, sans appel à UPCitemdb" do
      expect(HTTP).not_to receive(:timeout)
      %w[game_barcode movie_barcode].each do |action|
        get "/api/search/#{action}", params: { ean: "123" }
        expect(response).to have_http_status(403)
        expect(json).to include("premium" => true)
      end
    end

    it "recherches gratuites (dont le scan de livre par ISBN) : accessibles" do
      stub_http { fake_response(200, { items: [] }) }
      get "/api/search/book", params: { query: "9782070360024" }
      expect(response).to have_http_status(200)
    end
  end

  # Les deux services de code-barres et Claude sont simulés : titres bruts réels, relevés le 2026-10-27
  describe "GET /api/search/game_barcode" do
    let(:game) do
      { "id" => 1, "name" => "Zelda", "summary" => "A game", "cover" => { "url" => "//img/t_thumb/x.jpg" },
        "platforms" => [ { "name" => "Switch" } ], "genres" => [ { "name" => "RPG" } ], "first_release_date" => 1488499200 }
    end
    let(:diamond) do
      { "id" => 2, "name" => "Pokémon Diamond Version", "summary" => "Catch them",
        "alternative_names" => [ { "name" => "Pokémon Diamant", "comment" => "French title" } ] }
    end
    let(:white_2) { { "id" => 3, "name" => "Pokémon White Version 2", "summary" => "Catch them" } }
    let(:layton) do
      { "id" => 4, "name" => "Professor Layton and the Last Specter", "summary" => "Puzzles",
        "alternative_names" => [ { "name" => "Professeur Layton et l'Appel du Spectre", "comment" => "French title" } ] }
    end

    def scan(raw_title, names, **details)
      allow(BarcodeService).to receive(:product_title).with("123").and_return(raw_title)
      allow(BarcodeService).to receive(:product_details).with(raw_title, kind: :game).and_return(names: names, **details)
      allow(TranslationService).to receive(:translate_batch) { |texts| texts }
      get "/api/search/game_barcode", params: { ean: "123" }
    end

    it "code-barres inconnu des deux services : 404 avec fallback, sans appel à Claude" do
      allow(BarcodeService).to receive(:product_title).and_return(nil)
      expect(BarcodeService).not_to receive(:product_details)
      get "/api/search/game_barcode", params: { ean: "123" }
      expect(response).to have_http_status(404)
      expect(json["fallback"]).to be true
    end

    it "produit qui n'est pas un jeu (console, accessoire...) : 404 avec fallback" do
      scan("Nintendo DS Lite Black Pokemon Limited Edition", [])
      expect(response).to have_http_status(404)
      expect(json["fallback"]).to be true
    end

    it "annonce en vrac : le nom extrait par Claude trouve le bon jeu, en français" do
      expect_any_instance_of(controller_class).to receive(:igdb_search).with("Pokémon Diamond Version", limit: 3).and_return([ diamond ])
      scan("Game: Pokemon Diamant Edition for Nintendo DS + LITE + DSi + XL + 3DS 2DS", [ "Pokémon Diamond Version", "Pokémon Diamant" ])
      expect(json).to include("name" => "Pokémon Diamant", "original_name" => "Pokémon Diamond Version")
    end

    it "ce que dit la boîte : plateforme, édition, et le code-barres à garder avec l'item" do
      allow_any_instance_of(controller_class).to receive(:igdb_search).and_return([ diamond ])
      scan("Pokemon Diamant Edition Collector Nintendo DS", [ "Pokémon Diamond Version" ], platform: "Nintendo DS", edition: "Collector")
      expect(json).to include("platform" => "Nintendo DS", "edition" => "Collector", "barcode" => "123")
    end

    it "garde-fou : un jeu mieux classé mais au titre différent est écarté" do
      allow_any_instance_of(controller_class).to receive(:igdb_search).and_return([ white_2, diamond ])
      scan("Pokemon - Diamant Edition (nintendo Ds)", [ "Pokémon Diamond Version" ])
      expect(json["name"]).to eq("Pokémon Diamant")
    end

    it "garde-fou : aucun titre ne correspond, 404 plutôt qu'un mauvais jeu" do
      allow_any_instance_of(controller_class).to receive(:igdb_search).and_return([ white_2 ])
      scan("Pokemon - Diamant Edition (nintendo Ds)", [ "Pokémon Diamond Version", "Pokémon Diamant" ])
      expect(response).to have_http_status(404)
      expect(json["fallback"]).to be true
    end

    it "titre principal introuvable sur IGDB : le titre français prend le relais" do
      allow_any_instance_of(controller_class).to receive(:igdb_search) do |_controller, name, limit:|
        name == "Professeur Layton et l'Appel du Spectre" ? [ layton ] : []
      end
      scan("Nintendo Professeur Layton Et L'appel Du Spectre [ds], Good Nintendo Ds Video Ga",
           [ "Professor Layton and the Spectre's Call", "Professeur Layton et l'Appel du Spectre" ])
      expect(json["name"]).to eq("Professeur Layton et l'Appel du Spectre")
    end

    it "IGDB indisponible : 503" do
      allow_any_instance_of(controller_class).to receive(:igdb_search).and_return(nil)
      scan("Zelda - Nintendo Switch", [ "Zelda" ])
      expect(response).to have_http_status(503)
    end

    it "Claude indisponible : repli sur le nettoyage par règles, même JSON qu'avant" do
      allow(BarcodeService).to receive(:product_title).and_return("Zelda - Nintendo Switch")
      allow(BarcodeService).to receive(:product_details).and_raise(BarcodeService::Error, "API surchargée")
      expect_any_instance_of(controller_class).to receive(:igdb_search).with("Zelda", limit: 3).and_return([ game ])
      allow(TranslationService).to receive(:translate_batch).and_return([ "Un jeu" ])
      get "/api/search/game_barcode", params: { ean: "123" }
      expect(json).to include("name" => "Zelda", "summary" => "Un jeu", "platforms" => "Switch",
                              "release_date" => 2017, "cover_url" => "https://img/t_cover_big/x.jpg")
      expect(json["metadata"]).to include("release_date" => "2017-03-03", "genres" => "RPG")
    end
  end

  describe "GET /api/search/movie_barcode" do
    it "code-barres inconnu : 404 directement, sans appels inutiles à TMDB" do
      allow(BarcodeService).to receive(:product_title).and_return(nil)
      expect(HTTP).not_to receive(:timeout)
      get "/api/search/movie_barcode", params: { ean: "123" }
      expect(response).to have_http_status(404)
    end

    it "film trouvé : titre extrait par Claude, puis détails et réalisateur" do
      allow(BarcodeService).to receive(:product_title).and_return("Inception (DVD)")
      allow(BarcodeService).to receive(:product_details).with("Inception (DVD)", kind: :movie)
                                                       .and_return(names: [ "Inception" ], format: "Blu-ray", edition: "Steelbook")
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
      expect(json).to include("title" => "Inception", "year" => 2010, "director" => "Christopher Nolan", "studio" => "Warner",
                              "format" => "Blu-ray", "edition" => "Steelbook", "barcode" => "123")
    end

    it "garde-fou : aucun film au titre correspondant, 404 plutôt qu'un mauvais film" do
      allow(BarcodeService).to receive(:product_title).and_return("Amelie [DVD]")
      allow(BarcodeService).to receive(:product_details).and_return(names: [ "Le Fabuleux Destin d'Amélie Poulain" ])
      stub_http { fake_response(200, { results: [ { id: 1, title: "Les Misérables", original_title: "Les Misérables" } ] }) }
      get "/api/search/movie_barcode", params: { ean: "123" }
      expect(response).to have_http_status(404)
    end
  end

  describe "GET /api/search/search_game" do
    let(:sword) do
      { "id" => 1, "name" => "Pokémon Sword",
        "alternative_names" => [ { "name" => "Pokémon Schwert", "comment" => "German title" },
                                 { "name" => "Pokémon Épée", "comment" => "French title" } ] }
    end
    let(:zelda) { { "id" => 2, "name" => "The Legend of Zelda" } }

    # IGDB simulé : une réponse par endpoint, et les requêtes envoyées sont enregistrées
    let(:igdb_bodies) { {} }
    def stub_igdb(games:, alternative_names:)
      allow(IgdbService).to receive(:access_token).and_return("tok")
      igdb = double("client IGDB")
      allow(HTTP).to receive(:timeout).with(10).and_return(igdb)
      allow(igdb).to receive(:headers).and_return(igdb)
      allow(igdb).to receive(:post) do |url, body:|
        endpoint = url.split("/").last
        igdb_bodies[endpoint] = body
        result = { "games" => games, "alternative_names" => alternative_names }[endpoint]
        result.is_a?(Integer) ? fake_response(result, {}) : fake_response(200, result)
      end
    end

    it "développeur, et plateforme de l'appli seulement si le jeu n'existe que sur une seule" do
      one_platform = sword.merge("platforms" => [ { "name" => "Nintendo Switch" } ],
                                 "involved_companies" => [ { "developer" => true, "company" => { "name" => "Game Freak" } },
                                                           { "developer" => false, "company" => { "name" => "Nintendo" } } ])
      several = sword.merge("id" => 9, "platforms" => [ { "name" => "PlayStation 4" }, { "name" => "Xbox One" } ])
      stub_igdb(games: [ one_platform, several ], alternative_names: [])
      get "/api/search/search_game", params: { query: "pokemon" }
      games = json["games"].index_by { |game| game["id"] }
      expect(games[1]).to include("platform" => "Switch", "developer" => "Game Freak")
      expect(games[9]["platform"]).to be_nil
    end

    it "année de sortie européenne quand IGDB la connaît, sinon première sortie mondiale" do
      diamond = sword.merge("first_release_date" => 1159401600, # 2006 au Japon
                            "release_dates" => [ { "date" => 1159401600, "release_region" => 5 },
                                                 { "date" => 1185494400, "release_region" => 1 } ]) # 2007 en Europe
      japan_only = sword.merge("id" => 9, "first_release_date" => 1159401600, "release_dates" => [ { "date" => 1159401600, "release_region" => 5 } ])
      stub_igdb(games: [ diamond, japan_only ], alternative_names: [])
      get "/api/search/search_game", params: { query: "pokemon" }
      games = json["games"].index_by { |game| game["id"] }
      expect(games[1]).to include("release_date" => 2007)
      expect(games[1]["metadata"]).to include("release_date" => "2007-07-27")
      expect(games[9]).to include("release_date" => 2006)
    end

    it "affiche le titre français officiel, avec le titre d'origine en petit" do
      stub_igdb(games: [ sword ], alternative_names: [])
      get "/api/search/search_game", params: { query: "Pokemon Sword" }
      expect(json["games"].first).to include("name" => "Pokémon Épée", "original_name" => "Pokémon Sword")
    end

    it "garde le titre d'origine quand IGDB ne connaît pas de titre français" do
      stub_igdb(games: [ zelda ], alternative_names: [])
      get "/api/search/search_game", params: { query: "Zelda" }
      expect(json["games"].first).to include("name" => "The Legend of Zelda", "original_name" => nil)
    end

    it "trouve un jeu par son titre français, en premier et sans doublon" do
      stub_igdb(games: [ zelda, sword ], alternative_names: [ { "game" => sword } ])
      get "/api/search/search_game", params: { query: "Pokémon Épée" }
      expect(json["games"].map { |g| g["id"] }).to eq([ 1, 2 ])
      expect(igdb_bodies["alternative_names"]).to include('where name ~ *"Pokémon Épée"* & comment = "French title"')
    end

    it "fonctionne encore si seule la recherche française échoue" do
      stub_igdb(games: [ zelda ], alternative_names: 500)
      get "/api/search/search_game", params: { query: "Zelda" }
      expect(json["games"].map { |g| g["id"] }).to eq([ 2 ])
    end

    it "IGDB indisponible : 503" do
      stub_igdb(games: 500, alternative_names: [])
      get "/api/search/search_game", params: { query: "Zelda" }
      expect(response).to have_http_status(503)
    end

    it "retire les guillemets des deux requêtes IGDB et oublie un token expiré" do
      stub_igdb(games: 401, alternative_names: 401)
      expect(Rails.cache).to receive(:delete).with(IgdbService::CACHE_KEY).at_least(:once)
      get "/api/search/search_game", params: { query: 'Zelda" trick; fields *' }
      expect(igdb_bodies["games"]).to include('search "Zelda trick; fields *"')
      expect(igdb_bodies["alternative_names"]).to include('*"Zelda trick; fields *"*')
      expect(response).to have_http_status(503)
    end
  end

  describe "classement des jeux IGDB" do
    let(:fan_mod) { { "id" => 10, "name" => "Super Mario Odyssey F.L.U.D.D.", "game_type" => 5 } }
    let(:real_game) { { "id" => 11, "name" => "Super Mario Odyssey", "game_type" => 0, "total_rating_count" => 1902 } }
    let(:obscure) { { "id" => 12, "name" => "Super Mario Bros: Odyssey - Chapter 1", "game_type" => 0 } }

    it "écarte les mods et privilégie le titre identique, puis le plus populaire" do
      allow(IgdbService).to receive(:access_token).and_return("tok")
      igdb = double("client IGDB")
      allow(HTTP).to receive(:timeout).with(10).and_return(igdb)
      allow(igdb).to receive(:headers).and_return(igdb)
      allow(igdb).to receive(:post) do |url, body:|
        fake_response(200, url.end_with?("/games") ? [ fan_mod, obscure, real_game ] : [])
      end
      get "/api/search/search_game", params: { query: "Super Mario: Odyssey" }
      expect(json["games"].map { |g| g["id"] }).to eq([ 11, 12 ])
    end
  end

  describe "nettoyage des titres de jeux (repli quand Claude ne répond pas)" do
    {
      "Mario Kart 8 Deluxe - Nintendo Switch Video Game - European Version (International Version)" => "Mario Kart 8 Deluxe",
      "Luigi s Mansion 3 : Video Game for Nintendo Switch - Import Region Free" => "Luigi's Mansion 3",
      "Super Mario: Odyssey - Nintendo Switch" => "Super Mario: Odyssey",
      "Spider-Man PS4" => "Spider-Man",
      "Astro Bot PS5 - Standard Edition" => "Astro Bot",
      "Switch Sports" => "Switch Sports",
      "Nintendo Switch Sports - Nintendo Switch" => "Nintendo Switch Sports",
      "PC Building Simulator" => "PC Building Simulator"
    }.each do |raw, clean|
      it("#{raw} → #{clean}") { expect(controller_class.new.send(:clean_game_title, raw)).to eq(clean) }
    end
  end

  describe "nettoyage des titres de films (repli quand Claude ne répond pas)" do
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
