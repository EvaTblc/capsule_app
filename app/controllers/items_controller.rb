class ItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_collection
  before_action :set_item, only: [:show, :edit, :update, :destroy]

  def show
  end

  def new
    @item = Item.new
  end

  def create
    @item = Item.new(item_params)
    @item.collection = @collection
    if @item.save
      redirect_to collection_item_path(@collection, @item), notice: "Item ajouté !"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @item.update(item_params)
      redirect_to collection_item_path(@collection, @item), notice: "Item mis à jour !"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @item.destroy
    redirect_to @collection, notice: "Item supprimé."
  end

  private

  def set_collection
    @collection = Collection.find(params[:collection_id])
  end

  def set_item
    @item = @collection.items.find(params[:id])
  end

  def item_params
    params.require(:item).permit(:title, :description, :acquired_at, :condition, :barcode, :item_type)
  end
end
