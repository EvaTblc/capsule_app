class WishesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_collection
  before_action :set_wish, only: [ :edit, :update, :destroy ]

  def new
    @wish = @collection.wishes.new
  end

  def create
    @wish = @collection.wishes.new(wish_params)
    @wish.author = current_user
    @wish.product = catalog_product

    if @wish.save
      redirect_to @collection, notice: "Souhait ajouté !"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    @wish.assign_attributes(wish_params)
    @wish.product = catalog_product

    if @wish.save
      redirect_to @collection, notice: "Souhait modifié."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @wish.destroy
    redirect_to @collection, notice: "Souhait supprimé."
  end

  private

  def set_collection
    @collection = current_user.collections.find(params[:collection_id])
  end

  def set_wish
    @wish = @collection.wishes.find(params[:id])
  end

  def wish_params
    params.require(:wish).permit(:title, :platform, :edition, :max_price, :note)
  end

  # Jeu choisi via la recherche : on ne reçoit que son identifiant IGDB, l'œuvre est retrouvée côté serveur
  def catalog_product
    ProductCatalog.game(params.dig(:product, :igdb_id)) if params.dig(:product, :igdb_id).present?
  end
end
