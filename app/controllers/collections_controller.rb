class CollectionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_collection, only: [ :edit, :update, :destroy, :regenerate_invite ]
  before_action :set_visible_collection, only: [ :show ]
  before_action :check_owner!, only: [ :edit, :update, :destroy, :regenerate_invite ]

  def index
    @collections = current_user.collections.with_attached_cover_image.sort_by { |c| NaturalSort.key(c.title) }
    # Un seul COUNT groupé au lieu d'un par collection
    @item_counts = Item.where(collection: @collections).group(:collection_id).count
    # Seulement les 6 derniers items, au lieu de charger tous ceux de toutes les collections
    @recent_items = current_user.items.includes(collection: { cover_image_attachment: :blob }).with_attached_images.order(created_at: :desc).limit(6)
  end

  def show
    @items = @collection.items.includes(:item_detailable).sort_by { |i| NaturalSort.key(i.title) }
    @members = @collection.user_collections.includes(:user)
    # Visiteur d'une collection publique : lecture seule (pas d'édition, d'invitation, d'ajout ni de notes)
    @member = @collection.member?(current_user)
    # Seul le propriétaire modifie, partage le lien et gère les membres
    @owner = @collection.owner?(current_user)
  end

  def new
    @collection = Collection.new
  end

  def create
    @collection = Collection.new(collection_params)
    if @collection.save
      UserCollection.create(user: current_user, collection: @collection, role: "owner")
      redirect_to @collection, notice: "Collection créée !"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @collection.update(collection_params)
      redirect_to @collection, notice: "Collection mise à jour !"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @collection.destroy
    redirect_to collections_path, notice: "Collection supprimée."
  end

  # Nouveau lien d'invitation : l'ancien ne permet plus de rejoindre la collection
  def regenerate_invite
    @collection.regenerate_invite_token!
    redirect_to @collection, notice: "Nouveau lien créé : l'ancien ne fonctionne plus."
  end

  private

  def set_collection
    @collection = current_user.collections.find(params[:id])
  end

  def set_visible_collection
    @collection = Collection.visible_to(current_user).find(params[:id])
  end

  def check_owner!
    unless current_user.user_collections.find_by(collection: @collection)&.role == "owner"
      redirect_to @collection, alert: "Action réservée au propriétaire."
    end
  end

  def collection_params
    params.require(:collection).permit(:title, :description, :category, :public, :cover_image)
  end
end
