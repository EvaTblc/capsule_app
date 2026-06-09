class Scraper
require "open-uri"
require "nokogiri"
require "json"

  def self.call(department)
    url = "https://brocabrac.fr/#{department}/"
    html = URI.open(url, "User-Agent" => "Mozilla/5.0")
    doc = Nokogiri::HTML.parse(html)

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
