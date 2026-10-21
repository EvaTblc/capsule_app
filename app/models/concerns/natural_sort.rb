module NaturalSort
  # Clé de tri « humaine » : sans accents ni majuscules, nombres comparés comme des nombres.
  # ["Tome 10", "Tome 2", "Élan", "arbre"] → ["arbre", "Élan", "Tome 2", "Tome 10"]
  # (le tri par défaut de la base, comme celui de Ruby, compare les octets : majuscules d'abord, accents après le z)
  def self.key(text)
    I18n.transliterate(text.to_s).downcase.gsub(/\d+/) { |number| number.rjust(10, "0") }
  end
end
