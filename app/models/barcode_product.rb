# Ce que dit une boîte précise, identifiée par son code-barres (édition, format, éditeur...).
# Sert à pré-remplir le formulaire ; une fois l'item enregistré, c'est lui qui fait foi.
# product : l'œuvre, reliée par la validation d'un utilisateur (la dernière validation gagne).
class BarcodeProduct < ApplicationRecord
  SOURCES = %w[bnf upcitemdb ean_db].freeze

  enum :kind, Product::KINDS.index_with(&:itself), validate: true
  enum :source, SOURCES.index_with(&:itself), validate: true

  belongs_to :product, optional: true
  # Qui a validé en dernier : retrouver et corriger d'un coup les erreurs d'un compte (vidé si le compte est supprimé)
  belongs_to :confirmed_by, class_name: "User", optional: true

  # Une même boîte peut être lue sur 12 chiffres (UPC) ou 13 (EAN) : on garde les chiffres, complétés à 13.
  # S'applique aussi aux recherches : find_by(barcode: "045496464851") trouve « 0045496464851 »
  normalizes :barcode, with: ->(barcode) { barcode.to_s.gsub(/\D/, "").rjust(13, "0") }

  validates :barcode, format: { with: /\A\d{13}\z/ }, uniqueness: true
  validates :fetched_at, presence: true

  # Relie la boîte à l'œuvre choisie par un utilisateur à la validation du formulaire
  def confirm!(product, by:)
    update!(product: product, confirmed_by: by, confirmed_at: Time.current)
  end
end
