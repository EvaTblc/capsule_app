class ItemsController < ApplicationController
  before_action :authenticate_user!
  # Appels payants à Claude : pas plus de 10 par minute et par utilisateur
  rate_limit to: 10, within: 1.minute, by: -> { current_user&.id || request.remote_ip }, only: [ :identify, :estimate ]
  before_action :set_collection, except: [ :show, :estimate, :identify ]
  before_action :set_visible_collection, only: [ :show ]
  before_action :set_item, only: [ :show, :edit, :update, :destroy ]

  # Type d'item inconnu (ex. item[item_type]=User forgé) : requête invalide
  rescue_from ItemSaver::UnknownDetailType, with: -> { head :bad_request }

  def show
    # Visiteur d'une collection publique : lecture seule
    @member = @collection.member?(current_user)
  end

  def new
    @item = Item.new
  end

  def create
    @item = @collection.items.new

    if save_item
      if quick_add?
        # Ajout rapide : on reste dans le panneau pour enchaîner les jeux
        render turbo_stream: [
          turbo_stream.prepend("quick-add-list", partial: "items/quick_add_message",
                                                 locals: { message: "✓ #{@item.title}", error: false }),
          turbo_stream.replace("quick-add-form", helpers.tag.form(id: "quick-add-form"))
        ]
      else
        # Formulaire complet : direction la fiche du nouvel item
        redirect_to collection_item_path(@collection, @item), notice: "Item ajouté !"
      end
    elsif quick_add?
      # Le message s'affiche dans le panneau, le formulaire reste rempli
      render turbo_stream: turbo_stream.prepend("quick-add-list", partial: "items/quick_add_message",
                                                                  locals: { message: @item.errors.map(&:message).join(" · "), error: true }),
             status: :unprocessable_entity
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    return remove_image if params[:remove_image]

    if save_item
      redirect_to collection_item_path(@collection, @item), notice: "Item mis à jour !"
    else
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
    result = FigurineIdentificationService.identify_upload(params[:image])
    if result.error
      render json: { error: result.error }, status: result.status
    else
      render json: result.data
    end
  end

  private

  # Toute la logique d'enregistrement (détail, changement de type, transaction, tâches de fond) : ItemSaver
  def save_item
    type = params[:item][:item_type]
    detail_columns = ItemSaver.permitted_detail_columns(type) # lève UnknownDetailType si type inconnu
    ItemSaver.new(@item,
                  # images à part : les assigner remplacerait les photos existantes, ItemSaver les ajoute
                  item_attributes: item_params.except(:images),
                  detail_type: type,
                  detail_attributes: params.fetch(type.underscore, {}).permit(detail_columns).to_h,
                  images: params[:item][:images]).save
  end

  def remove_image
    @item.images.find(params[:remove_image]).purge
    redirect_to edit_collection_item_path(@collection, @item)
  end

  def item_params
    params.require(:item).permit(:title, :description, :acquired_at, :condition, :barcode, :comment, images: [])
  end

  # Turbo envoie les deux formulaires avec le même en-tête Accept (Turbo Stream accepté) :
  # c'est le champ caché du panneau d'ajout rapide qui permet de choisir la bonne réponse
  def quick_add?
    params[:quick_add].present?
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
end
