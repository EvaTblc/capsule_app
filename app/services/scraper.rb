class Scraper
require "open-uri"
require "nokogiri"
require "json"

  class NetworkError < StandardError; end
  class ParseError < StandardError; end

  def self.call(department)
    raise ArgumentError, "Department manquant" if department.blank?

    url = "https://brocabrac.fr/#{department}/"
    html = begin
      URI.open(url, "User-Agent" => "Mozilla/5.0")
    rescue SocketError, Errno::ECONNREFUSED => e
      raise NetworkError, "Connexion impossible : #{e.message}"
    end
    doc = Nokogiri::HTML.parse(html)
    events = doc.search(".ev script[type='application/ld+json']")
    raise ParseError, "Structure HTML inattendue — le scraper doit être mis à jour" if events.empty?

    doc.search(".ev script[type='application/ld+json']").filter_map do |script|
      data = JSON.parse(script.text)

      next if data["eventStatus"] == "http://schema.org/EventCancelled"

      {
        title: data["name"],
        date: data["startDate"]&.to_date,
        city: data.dig("location", "address", "addressLocality"),
        address: data.dig("location", "address", "streetAddress"),
        latitude: data.dig("location", "geo", "latitude"),
        longitude: data.dig("location", "geo", "longitude"),
        category: data["@type"],
        url: data["url"]
      }
    rescue JSON::ParserError
      nil
    end
  end
end
