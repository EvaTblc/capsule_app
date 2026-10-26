class Scraper
  class NetworkError < StandardError; end
  class ParseError < StandardError; end

  # Code département au format des URL Brocabrac, nil si non couvert.
  # Brocabrac ne couvre que la métropole : 01 à 95, avec 2a/2b pour la Corse (pas de DOM).
  def self.department_for(postal_code)
    code = postal_code.to_s.strip
    return nil unless code.match?(/\A\d{5}\z/)
    # Corse : 200xx-201xx = Corse-du-Sud, 202xx-206xx = Haute-Corse
    return code < "20200" ? "2a" : "2b" if code.start_with?("20")

    department = code.first(2)
    department.to_i.between?(1, 95) ? department : nil
  end

  def self.call(department)
    raise ArgumentError, "Department manquant" if department.blank?

    url = "https://brocabrac.fr/#{department}/"
    response = begin
      # follow : suit les redirections (open-uri le faisait tout seul, pas la gem http)
      HTTP.follow(max_hops: 3)
          .timeout(connect: 5, read: 10)
          .headers("User-Agent" => "Mozilla/5.0")
          .get(url)
    rescue HTTP::Error => e # connexion refusée, DNS, timeout, trop de redirections
      raise NetworkError, "Connexion impossible : #{e.message}"
    end
    raise NetworkError, "Brocabrac a répondu #{response.status}" unless response.status.success?

    doc = Nokogiri::HTML.parse(response.body.to_s)
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
