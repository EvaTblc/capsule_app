require "rails_helper"

RSpec.describe Scraper do
  describe ".call" do
    context "quand le département est nil" do
      it "lève une ArgumentError" do
        expect { Scraper.call(nil) }.to raise_error(ArgumentError)
      end
    end

    context "quand le département est vide" do
      it "lève une ArgumentError" do
        expect { Scraper.call("") }.to raise_error(ArgumentError)
      end
    end

    # Client HTTP simulé : renvoie la page donnée, ou lève l'erreur donnée
    def stub_brocabrac(status: 200, html: "", error: nil)
      client = double("client HTTP")
      allow(HTTP).to receive(:follow).with(max_hops: 3).and_return(client)
      allow(client).to receive(:timeout).and_return(client)
      allow(client).to receive(:headers).and_return(client)
      if error
        allow(client).to receive(:get).and_raise(error)
      else
        response = HTTP::Response.new(status: status, body: html, version: "1.1",
                                      request: HTTP::Request.new(verb: :get, uri: "https://brocabrac.fr/44/"))
        allow(client).to receive(:get).with("https://brocabrac.fr/44/").and_return(response)
      end
    end

    context "quand la page contient des brocantes" do
      it "renvoie les événements, sans ceux annulés" do
        event = ->(name, status = "http://schema.org/EventScheduled") do
          %(<div class="ev"><script type="application/ld+json">#{
            { name: name, startDate: "2026-11-01", eventStatus: status, url: "https://brocabrac.fr/#{name}",
              location: { address: { addressLocality: "Nantes", streetAddress: "Place" }, geo: { latitude: 47.2, longitude: -1.5 } } }.to_json
          }</script></div>)
        end
        stub_brocabrac(html: "<html>#{event.("vide-grenier")}#{event.("annule", "http://schema.org/EventCancelled")}</html>")

        events = Scraper.call("44")
        expect(events.map { |e| e[:title] }).to eq([ "vide-grenier" ])
        expect(events.first).to include(city: "Nantes", date: Date.new(2026, 11, 1), latitude: 47.2)
      end
    end

    context "quand le site est inaccessible" do
      it "lève une NetworkError" do
        stub_brocabrac(error: HTTP::ConnectionError.new("failed to connect"))
        expect { Scraper.call("44") }.to raise_error(Scraper::NetworkError)
      end
    end

    context "quand le site est trop lent" do
      it "lève une NetworkError" do
        stub_brocabrac(error: HTTP::TimeoutError.new("Read timed out"))
        expect { Scraper.call("44") }.to raise_error(Scraper::NetworkError)
      end
    end

    context "quand le site répond en erreur" do
      it "lève une NetworkError (open-uri le faisait aussi)" do
        stub_brocabrac(status: 404, html: "Not found")
        expect { Scraper.call("44") }.to raise_error(Scraper::NetworkError, /404/)
      end
    end

    context "quand la structure HTML a changé" do
      it "lève une ParseError" do
        stub_brocabrac(html: "<html></html>")
        expect { Scraper.call("44") }.to raise_error(Scraper::ParseError)
      end
    end
  end

  describe ".department_for" do
    {
      "44000" => "44", "75011" => "75", "01000" => "01", " 44000 " => "44",
      "20000" => "2a", "20167" => "2a", "20200" => "2b", "20600" => "2b", # Corse
      "97110" => nil, "97400" => nil, "98000" => nil,                       # DOM-TOM : pas sur Brocabrac
      "00000" => nil, "4400" => nil, nil => nil
    }.each do |postal_code, department|
      it "#{postal_code.inspect} → #{department.inspect}" do
        expect(Scraper.department_for(postal_code)).to eq(department)
      end
    end
  end
end
