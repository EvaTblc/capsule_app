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

    context "quand le site est trop lent" do
      it "lève une NetworkError" do
        allow(URI).to receive(:open).and_raise(Net::ReadTimeout)
        expect { Scraper.call("44") }.to raise_error(Scraper::NetworkError)
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
