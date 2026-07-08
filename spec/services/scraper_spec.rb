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

    context "quand le site est inaccessible" do
      it "lève une NetworkError" do
        allow(URI).to receive(:open).and_raise(SocketError)
        expect { Scraper.call("44") }.to raise_error(Scraper::NetworkError)
      end
    end

    context "quand la structure HTML a changé" do
      it "lève une ParseError" do
        allow(URI).to receive(:open).and_return(StringIO.new("<html></html>"))
        empty_doc = Nokogiri::HTML("<html></html>")
        
        allow(Nokogiri::HTML).to receive(:parse).and_return(empty_doc)
        expect { Scraper.call("44") }.to raise_error(Scraper::ParseError)
      end
    end
  end
end
