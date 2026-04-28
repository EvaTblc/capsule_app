class CollectionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_collection, only: [:show, :edit, :update, :destroy]
  before_action :check_owner!, only: [:edit, :update, :destroy]

  def index
    @collections = current_user.collections
  end

  def show
    @items = @collection.items
    @members = @collection.user_collections.includes(:user)
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

  private

  def set_collection
    @collection = Collection.find(params[:id])
  end

  def check_owner!
    unless current_user.user_collections.find_by(collection: @collection)&.role == "owner"
      redirect_to @collection, alert: "Action réservée au propriétaire."
    end
  end

  def collection_params
    params.require(:collection).permit(:title, :description, :category, :public)
  end
end
