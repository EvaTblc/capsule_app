# Catalogue partagé : une œuvre (jeu, film, livre), quelle que soit son édition.
# Ne contient que des données officielles récupérées par le serveur (IGDB, Wikidata, Wikipédia, BnF),
# jamais les valeurs saisies dans un formulaire : ce qui est personnel reste sur l'item.
# Rien de TMDB n'y est stocké, sauf son identifiant (fourni par Wikidata, CC0).
class Product < ApplicationRecord
  KINDS = %w[game movie book].freeze
  # Au-delà, les données sont rafraîchies à la prochaine utilisation
  REFRESH_AFTER = 6.months

  enum :kind, KINDS.index_with(&:itself), validate: true

  # La base vide aussi ces références (on_delete: :nullify) : les boîtes et les items restent intacts
  has_many :barcode_products, dependent: :nullify
  has_many :items, dependent: :nullify

  validates :title, :fetched_at, presence: true
  # Doublons des index uniques, pour un message propre au lieu d'une exception
  validates :igdb_id, :tmdb_id, :wikidata_id, uniqueness: true, allow_nil: true

  def stale?
    fetched_at < REFRESH_AFTER.ago
  end
end
