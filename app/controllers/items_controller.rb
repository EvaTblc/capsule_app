class ItemsController < ApplicationController
  DETAIL_TYPES = Item::ITEM_TYPE_STYLES.keys.freeze

  before_action :authenticate_user!
  before_action :set_collection, except: [ :show, :estimate, :identify ]
  before_action :set_visible_collection, only: [ :show ]
  before_action :set_item, only: [ :show, :edit, :update, :destroy ]

  def show
    # Visiteur d'une collection publique : lecture seule
    @member = @collection.member?(current_user)
  end

  def new
    @item = Item.new
  end

  def create
    item_type = params[:item][:item_type]
    attrs = prepare_new_detail_attrs(item_type, permitted_detail_params(item_type))

    detail = detail_class(item_type).new(attrs)
    @item = Item.new(item_params)
    @item.collection = @collection
    @item.item_detailable = detail

    # Le détail et l'item sont créés ensemble ou pas du tout
    saved = Item.transaction do
      raise ActiveRecord::Rollback unless detail.save && @item.save
      true
    end

    if saved
      enqueue_detail_jobs(translate: item_type == "VideoGameDetail")

      if quick_add?
        # Ajout rapide : on reste dans le panneau pour enchaîner les jeux
        render turbo_stream: [
          turbo_stream.prepend("quick-add-list",
            helpers.tag.div("✓ #{@item.title}",
              class: "bg-purple-50 rounded-xl px-4 py-2 text-sm font-semibold text-purple-700")
          ),
          turbo_stream.replace("quick-add-form",
            helpers.tag.form(id: "quick-add-form")
          )
        ]
      else
        # Formulaire complet : direction la fiche du nouvel item
        redirect_to collection_item_path(@collection, @item), notice: "Item ajouté !"
      end
    else
      collect_errors(detail)
      if quick_add?
        # Le message s'affiche dans le panneau, le formulaire reste rempli
        render turbo_stream: turbo_stream.prepend("quick-add-list",
          helpers.tag.div(@item.errors.map(&:message).join(" · "),
            class: "bg-red-50 rounded-xl px-4 py-2 text-sm font-semibold text-red-600")
        ), status: :unprocessable_entity
      else
        render :new, status: :unprocessable_entity
      end
    end
  end

  def edit; end

  def update
    if params[:remove_image]
      image = @item.images.find(params[:remove_image])
      image.purge
      redirect_to edit_collection_item_path(@collection, @item)
      return
    end
    new_type = params[:item][:item_type]
    attrs = permitted_detail_params(new_type)

    old_detail = nil
    needs_translation = false
    if new_type != @item.item_type
      old_detail = @item.item_detailable
      @item.item_detailable = detail_class(new_type).new(prepare_new_detail_attrs(new_type, attrs))
      needs_translation = new_type == "VideoGameDetail"
    elsif attrs.any?
      # On ne retraduit que si la description a changé (ex : nouveau jeu choisi via la recherche)
      if new_type == "VideoGameDetail" && attrs["description"].present? && attrs["description"] != @item.item_detailable.description
        attrs = prepare_new_detail_attrs(new_type, attrs).merge("description" => nil)
        needs_translation = true
      end
      @item.item_detailable.assign_attributes(attrs)
    end

    # Détail et item enregistrés ensemble ou pas du tout
    # (images exclu : l'assigner remplacerait toutes les images existantes)
    # Assigné avant : en cas d'échec, l'item reste cohérent avec son nouveau détail pour réafficher le formulaire
    @item.assign_attributes(item_params.except(:images))
    saved = Item.transaction do
      raise ActiveRecord::Rollback unless @item.item_detailable.save && @item.save
      true
    end

    if saved
      @item.images.attach(params[:item][:images]) if params[:item][:images].present?
      # L'ancien détail n'est supprimé qu'une fois l'item bien rattaché au nouveau
      old_detail&.destroy
      enqueue_detail_jobs(translate: needs_translation)
      redirect_to collection_item_path(@collection, @item), notice: "Item mis à jour !"
    else
      collect_errors(@item.item_detailable)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @item.destroy
    redirect_to @collection, notice: "Item supprimé."
  end

  def estimate
    @item = current_user.items.find(params[:id])
    estimation = EstimationService.estimate(@item)
    render turbo_stream: turbo_stream.update("estimation",
      partial: "items/estimation",
      locals: { estimation: estimation })
  end

  def identify
    base64 = params[:image]
    result = FigurineIdentificationService.identify(base64)
    render json: result
  end

  private

  def item_params
    params.require(:item).permit(:title, :description, :acquired_at, :condition, :barcode, :item_type, :comment, images: [])
  end

  def set_collection
    @collection = current_user.collections.find(params[:collection_id])
  end

  def set_visible_collection
    @collection = Collection.visible_to(current_user).find(params[:collection_id])
  end

  def set_item
    @item = @collection.items.find(params[:id])
  end

  def detail_class(type)
    raise ActionController::BadRequest unless DETAIL_TYPES.include?(type)
    type.constantize
  end

  # Seules les vraies colonnes du modèle sont acceptées (pas id, created_at...)
  def permitted_detail_params(type)
    permitted = detail_class(type).column_names - %w[id created_at updated_at]
    params.fetch(type.underscore, {}).permit(permitted).to_h
  end

  # Préparation commune à tout nouveau détail (création ou changement de type)
  def prepare_new_detail_attrs(type, attrs)
    case type
    when "VideoGameDetail"
      # Traduit plus tard par TranslationJob. Le formulaire complet envoie le résumé dans description,
      # l'ajout rapide directement dans summary_en : on ne l'écrase pas quand description est absente
      description = attrs.delete("description")
      attrs["summary_en"] = description if description.present?
    end
    attrs
  end

  # Turbo envoie les deux formulaires avec le même en-tête Accept (Turbo Stream accepté) :
  # c'est le champ caché du panneau d'ajout rapide qui permet de choisir la bonne réponse
  def quick_add?
    params[:quick_add].present?
  end

  # Après un échec : réunit sur @item ses propres erreurs et celles du détail, pour les afficher ensemble.
  # (si le détail a échoué en premier, l'item n'a pas encore été validé)
  def collect_errors(detail)
    @item.validate
    detail.errors.each { |error| @item.errors.add(:base, error.full_message) }
  end

  # Complète le détail en arrière-plan, pour ne pas faire attendre l'utilisateur pendant l'appel à Claude :
  # traduction du résumé (jeux) ou génération d'un résumé (livres sans description)
  def enqueue_detail_jobs(translate:)
    TranslationJob.perform_later(@item.id) if translate
    if @item.item_detailable_type == "BookDetail" && @item.item_detailable.description.blank?
      BookDescriptionJob.perform_later(@item.id)
    end
  end
end
