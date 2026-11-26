class WishesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_collection

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

  private

  def set_collection
    @collection = current_user.collections.find(params[:collection_id])
  end

  def wish_params
    params.require(:wish).permit(:title, :platform, :edition, :max_price, :note)
  end

  # Jeu choisi via la recherche : on ne reçoit que son identifiant IGDB, l'œuvre est retrouvée côté serveur
  def catalog_product
    ProductCatalog.game(params.dig(:product, :igdb_id)) if params.dig(:product, :igdb_id).present?
  end
end
