class BnfService
  URL = "https://catalogue.bnf.fr/api/SRU".freeze
  # Espace de noms des balises mxc: dans les réponses de la BnF
  NS = { "mxc" => "info:lc/xmlns/marcxchange-v2" }.freeze
  # Type de notice (7e caractère de l'en-tête) → type de produit de l'appli ; les autres (musique, images...) ne nous concernent pas
  KINDS = { "l" => "game", "g" => "movie", "a" => "book" }.freeze


  def self.find_by_ean(ean)
    ean = ean.to_s
    return nil unless ean.match?(/\A\d{8,14}\z/)
    # La BnF enregistre le code tel qu'imprimé : 12 chiffres (UPC) ou 13 (EAN), on cherche les deux
    ean13 = ean.rjust(13, "0")
    # Livres anciens (avant 2007) : catalogués sous leur ISBN à 10 chiffres, qu'on recalcule à partir de l'EAN
    codes = [ ean, ean13, ean13.delete_prefix("0"), isbn10(ean13) ].compact.uniq.join(" ")

    response = HTTP.timeout(10).get(URL, params: {
      version: "1.2",
      operation: "searchRetrieve",
      recordSchema: "unimarcxchange",
      maximumRecords: 1,
      query: "bib.ean any \"#{codes}\" or bib.isbn any \"#{codes}\""
    })
    unless response.status.success?
      Rails.logger.warn("[bnf] #{response.status} pour #{ean}")
      return nil
    end

    doc = Nokogiri::XML(response.body.to_s)
    record = doc.at_xpath("//mxc:record", NS)
    return nil unless record

    {
      kind: kind(record),
      bnf_ark: record[:id],
      title: subfield(record, "200", "a"),
      complement: subfield(record, "200", "e"),
      support: subfield(record, "215", "a"),
      publisher: (subfields(record, "210", "c").last || subfields(record, "214", "c").last)&.sub(/\s*\[.*\]\z/, ""),
      release_year: (subfield(record, "210", "d") || subfield(record, "214", "d"))&.[](/\d{4}/)&.to_i,
      creators: creators(record)
    }
  rescue HTTP::Error => e
    Rails.logger.warn("[bnf] #{e.class} pour #{ean}")
    nil
  end
  # Désignation du support (200$b), quand l'en-tête ne suffit pas
  DESIGNATIONS = { "Ressource électronique" => "game", "Images animées" => "movie", "Texte imprimé" => "book" }.freeze

  # Type de produit : 7e caractère de l'en-tête. Notices anciennes à l'en-tête incomplet (« \s\s\s\s\sa\s\s\s\s22… ») :
  # le type est décalé d'un caractère. En dernier recours, la désignation du support (200$b)
  def self.kind(record)
    leader = record.at_xpath("mxc:leader", NS)&.text.to_s
    type = leader[6].to_s.strip.presence || leader[5].to_s.strip
    KINDS[type] || DESIGNATIONS[subfield(record, "200", "b")]
  end

  # ISBN à 10 chiffres d'un EAN de livre en 978 (9782070360024 → 2070360024), nil sinon.
  # Dernier chiffre : clé de contrôle modulo 11 (« X » pour 10)
  def self.isbn10(ean13)
    return nil unless ean13.start_with?("978")

    digits = ean13[3, 9]
    key = (11 - digits.chars.each_with_index.sum { |digit, i| digit.to_i * (10 - i) } % 11) % 11
    digits + (key == 10 ? "X" : key.to_s)
  end

  # Texte d'une sous-zone de la notice, ex. subfield(record, "200", "a") → le titre
  def self.subfield(record, tag, code)
    record.at_xpath("mxc:datafield[@tag='#{tag}']/mxc:subfield[@code='#{code}']", NS)&.text
  end

  # Toutes les valeurs d'une sous-zone répétée, ex. les deux éditeurs de la zone 210
  def self.subfields(record, tag, code)
    record.xpath("mxc:datafield[@tag='#{tag}']/mxc:subfield[@code='#{code}']", NS).map(&:text)
  end

  # Contributeurs par rôle
  def self.creators(record)
    result = {}
    record.xpath("mxc:datafield[starts-with(@tag, '70') or starts-with(@tag, '71')]", NS).each do |field|
      last_name = field.at_xpath("mxc:subfield[@code='a']", NS)&.text
      first_name = field.at_xpath("mxc:subfield[@code='b']", NS)&.text
      name = [ first_name, last_name ].compact.join(" ")

      field.xpath("mxc:subfield[@code='4']", NS).each do |role|
        (result[role.text] ||= []) << name
      end
    end
    result
  end
  private_class_method :kind, :isbn10, :subfield, :subfields, :creators
end
