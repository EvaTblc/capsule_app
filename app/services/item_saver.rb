# Enregistre un item et son détail (livre, jeu, film...) ensemble, en création comme en modification :
# - construit le détail, ou le remplace si le type d'item change
# - enregistre les deux dans une même transaction (tout ou rien)
# - décide des tâches de fond : traduction du résumé d'un jeu, résumé généré d'un livre
# - en cas d'échec, regroupe sur l'item ses erreurs et celles du détail, pour les afficher ensemble
class ItemSaver
  DETAIL_TYPES = Item::ITEM_TYPE_STYLES.keys.freeze

  class UnknownDetailType < StandardError; end

  # Liste blanche : jamais de constantize sur une valeur envoyée par le navigateur sans vérification
  def self.detail_class(type)
    raise UnknownDetailType, type.inspect unless DETAIL_TYPES.include?(type)

    type.constantize
  end

  # Colonnes acceptées pour un détail : les vraies colonnes du modèle, sauf les techniques (id, dates)
  def self.permitted_detail_columns(type)
    detail_class(type).column_names - %w[id created_at updated_at]
  end

  attr_reader :item

  # images : nouvelles photos, ajoutées aux existantes (jamais assignées : ça remplacerait les autres)
  def initialize(item, item_attributes:, detail_type:, detail_attributes:, images: nil)
    @item = item
    @item_attributes = item_attributes
    @detail_type = detail_type
    @detail_attributes = detail_attributes
    @images = images
  end

  def save
    build_detail
    # Assigné après build_detail (qui compare avec l'ancien type) et avant l'enregistrement :
    # en cas d'échec, l'item reste cohérent avec son nouveau détail pour réafficher le formulaire
    item.assign_attributes(@item_attributes)

    saved = Item.transaction do
      raise ActiveRecord::Rollback unless item.item_detailable.save && item.save

      true
    end
    saved ? after_save : collect_errors
    saved.present?
  end

  private

  def build_detail
    @replaced_detail = nil
    @translate = false

    if item.new_record? || @detail_type != item.item_type
      # Nouveau détail : création, ou changement de type (l'ancien n'est supprimé qu'après succès)
      @replaced_detail = item.item_detailable
      item.item_detailable = self.class.detail_class(@detail_type).new(prepare_new_detail(@detail_attributes))
      @translate = @detail_type == "VideoGameDetail"
    elsif @detail_attributes.any?
      attributes = @detail_attributes
      if description_to_translate?(attributes)
        # Nouveau résumé (ex. autre jeu choisi via la recherche) : retraduit en arrière-plan
        attributes = prepare_new_detail(attributes).merge("description" => nil)
        @translate = true
      end
      item.item_detailable.assign_attributes(attributes)
    end
  end

  # On ne retraduit que si la description d'un jeu a changé, pas à chaque enregistrement
  def description_to_translate?(attributes)
    @detail_type == "VideoGameDetail" &&
      attributes["description"].present? &&
      attributes["description"] != item.item_detailable.description
  end

  # Jeu : le résumé (anglais) part dans summary_en, traduit ensuite par TranslationJob.
  # Le formulaire complet l'envoie dans description, l'ajout rapide directement dans summary_en :
  # on ne l'écrase pas quand description est absente
  def prepare_new_detail(attributes)
    attributes = attributes.dup
    if @detail_type == "VideoGameDetail"
      description = attributes.delete("description")
      attributes["summary_en"] = description if description.present?
    end
    attributes
  end

  def after_save
    item.images.attach(@images) if @images.present?
    @replaced_detail&.destroy
    enqueue_detail_jobs
  end

  # Tâches de fond, pour ne pas faire attendre l'utilisateur pendant l'appel à Claude
  def enqueue_detail_jobs
    TranslationJob.perform_later(item.id) if @translate
    if item.item_detailable_type == "BookDetail" && item.item_detailable.description.blank?
      BookDescriptionJob.perform_later(item.id)
    end
  end

  # Si le détail a échoué en premier, l'item n'a pas encore été validé : on le valide pour tout afficher
  def collect_errors
    item.validate
    item.item_detailable.errors.each { |error| item.errors.add(:base, error.full_message) }
  end
end
