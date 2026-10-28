require "rails_helper"

RSpec.describe ProductCatalog do
  # Réponse d'IGDB simulée (IgdbService.game) : données réelles de Pokémon Diamant
  let(:diamond) do
    { "id" => 1560, "name" => "Pokémon Diamond Version", "summary" => "Catch them all",
      "first_release_date" => 1159401600,
      "release_dates" => [ { "date" => 1185494400, "release_region" => 1 } ],
      "alternative_names" => [ { "name" => "Pokémon Diamant", "comment" => "French title" } ],
      "involved_companies" => [ { "developer" => true, "company" => { "name" => "Game Freak" } },
                                { "developer" => false, "company" => { "name" => "Nintendo" } } ],
      "genres" => [ { "name" => "Role-playing (RPG)" } ], "platforms" => [ { "name" => "Nintendo DS" } ] }
  end

  describe ".game" do
    it "jeu inconnu du catalogue : lu chez IGDB et enregistré (titre français, année européenne, développeur)" do
      allow(IgdbService).to receive(:game).with(1560).and_return(diamond)
      product = described_class.game("1560")
      expect(product).to be_persisted
      expect(product).to have_attributes(kind: "game", igdb_id: 1560, title: "Pokémon Diamant",
                                         original_title: "Pokémon Diamond Version", release_year: 2007, creator: "Game Freak")
      expect(product.details).to include("summary_en" => "Catch them all", "genres" => [ "Role-playing (RPG)" ],
                                         "platforms" => [ "Nintendo DS" ])
    end

    it "déjà au catalogue et récent : renvoyé sans appeler IGDB" do
      product = create(:product, igdb_id: 1560)
      expect(IgdbService).not_to receive(:game)
      expect(described_class.game(1560)).to eq(product)
    end

    it "plus de 6 mois : rafraîchi chez IGDB, la traduction gardée si le résumé n'a pas changé" do
      product = create(:product, igdb_id: 1560, title: "Ancien titre", description: "Attrapez-les tous",
                                 details: { "summary_en" => "Catch them all" }, fetched_at: 7.months.ago)
      allow(IgdbService).to receive(:game).and_return(diamond)
      expect(described_class.game(1560)).to eq(product)
      expect(product.reload).to have_attributes(title: "Pokémon Diamant", description: "Attrapez-les tous")
      expect(product.fetched_at).to be > 1.minute.ago
    end

    it "résumé modifié chez IGDB : l'ancienne traduction est effacée (elle sera refaite)" do
      product = create(:product, igdb_id: 1560, description: "Ancienne traduction",
                                 details: { "summary_en" => "Old summary" }, fetched_at: 7.months.ago)
      allow(IgdbService).to receive(:game).and_return(diamond)
      described_class.game(1560)
      expect(product.reload.description).to be_nil
    end

    it "IGDB indisponible : la version connue est gardée, même ancienne ; rien si le jeu est inconnu" do
      product = create(:product, igdb_id: 1560, fetched_at: 7.months.ago)
      allow(IgdbService).to receive(:game).and_return(nil)
      expect(described_class.game(1560)).to eq(product)
      expect(described_class.game(999)).to be_nil
      expect(Product.count).to eq(1)
    end

    it "identifiant invalide : nil, sans appel à IGDB" do
      expect(IgdbService).not_to receive(:game)
      [ nil, "", "abc", "12; drop", "-3", "0" ].each { |id| expect(described_class.game(id)).to be_nil }
    end
  end

  describe ".movie" do
    let(:intouchables) do
      { wikidata_id: "Q595", title: "Intouchables", original_title: "Intouchables", release_year: 2011,
        directors: [ "Olivier Nakache", "Éric Toledano" ], studios: [ "Gaumont" ], wikipedia_title: "Intouchables (film)" }
    end
    let(:summary) { { text: "Intouchables est une comédie dramatique…", url: "https://fr.wikipedia.org/wiki/Intouchables_(film)" } }

    it "film inconnu du catalogue : fiche Wikidata et résumé Wikipédia, rien de TMDB sauf l'identifiant" do
      allow(WikimediaService).to receive(:movie).with(77338).and_return(intouchables)
      allow(WikimediaService).to receive(:summary).with("Intouchables (film)").and_return(summary)
      product = described_class.movie("77338")
      expect(product).to have_attributes(kind: "movie", tmdb_id: 77338, wikidata_id: "Q595", title: "Intouchables",
                                         original_title: nil, release_year: 2011, creator: "Olivier Nakache, Éric Toledano",
                                         description: summary[:text], description_source: "wikipedia")
      expect(product.details).to include("studios" => [ "Gaumont" ], "wikipedia_url" => summary[:url])
    end

    it "déjà au catalogue et récent : renvoyé sans appeler Wikidata" do
      product = create(:product, :movie, tmdb_id: 77338)
      expect(WikimediaService).not_to receive(:movie)
      expect(described_class.movie(77338)).to eq(product)
    end

    it "film inconnu de Wikidata : nil (pas de fiche faite avec les données de TMDB)" do
      allow(WikimediaService).to receive(:movie).and_return(nil)
      expect(described_class.movie(77338)).to be_nil
    end

    it "Wikipédia muet au rafraîchissement : le résumé déjà connu est gardé" do
      product = create(:product, :movie, tmdb_id: 77338, description: "Résumé connu", description_source: "wikipedia", fetched_at: 7.months.ago)
      allow(WikimediaService).to receive(:movie).and_return(intouchables)
      allow(WikimediaService).to receive(:summary).and_return(nil)
      described_class.movie(77338)
      expect(product.reload).to have_attributes(description: "Résumé connu", description_source: "wikipedia")
    end
  end

  describe ".book" do
    let(:potter) do
      { wikidata_id: "Q43361", title: "Harry Potter à l'école des sorciers", original_title: "Harry Potter and the Philosopher's Stone",
        release_year: 1997, authors: [ "J. K. Rowling" ], genres: [ "fantasy" ], wikipedia_title: "Harry Potter à l'école des sorciers" }
    end

    it "œuvre lue chez Wikidata, avec le résumé de Wikipédia" do
      allow(WikimediaService).to receive(:book).with("Q43361").and_return(potter)
      allow(WikimediaService).to receive(:summary).and_return(text: "Premier tome de la saga…", url: "https://fr.wikipedia.org/wiki/Harry_Potter")
      expect(described_class.book("Q43361")).to have_attributes(
        kind: "book", wikidata_id: "Q43361", title: "Harry Potter à l'école des sorciers",
        original_title: "Harry Potter and the Philosopher's Stone", release_year: 1997, creator: "J. K. Rowling",
        description: "Premier tome de la saga…", description_source: "wikipedia"
      )
    end

    it "sans article Wikipédia : le résumé généré par Claude, déjà gardé, n'est pas effacé au rafraîchissement" do
      product = create(:product, :book, wikidata_id: "Q43361", description: "Résumé généré", description_source: "claude_generated",
                                        fetched_at: 7.months.ago)
      allow(WikimediaService).to receive(:book).and_return(potter.merge(wikipedia_title: nil))
      allow(WikimediaService).to receive(:summary).and_return(nil)
      described_class.book("Q43361")
      expect(product.reload).to have_attributes(description: "Résumé généré", description_source: "claude_generated")
    end

    it "l'identifiant d'un film du catalogue ne renvoie pas ce film" do
      create(:product, :movie, wikidata_id: "Q595")
      allow(WikimediaService).to receive(:book).with("Q595").and_return(nil) # Intouchables n'a pas d'auteur (P50)
      expect(described_class.book("Q595")).to be_nil
    end
  end
end
