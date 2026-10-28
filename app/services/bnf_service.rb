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
    codes = [ ean, ean13, ean13.delete_prefix("0") ].uniq.join(" ")

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
      kind: KINDS[record.at_xpath("mxc:leader", NS)&.text.to_s[6]],
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
  private_class_method :subfield, :subfields, :creators
end
