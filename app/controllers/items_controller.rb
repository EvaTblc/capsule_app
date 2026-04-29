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
    # 1. On identifie le type de detail
    item_type = params[:item][:item_type]

    # 2. On crée le bon detail model
    detail = case item_type
            when "BookDetail"      then BookDetail.new(params[:book_detail].permit!)
            when "VideoGameDetail" then VideoGameDetail.new(params[:video_game_detail].permit!)
            when "MovieDetail"     then MovieDetail.new(params[:movie_detail].permit!)
            when "MusicDetail"     then MusicDetail.new(params[:music_detail].permit!)
            when "FigurineDetail"  then FigurineDetail.new(params[:figurine_detail].permit!)
            when "TcgDetail"       then TcgDetail.new(params[:tcg_detail].permit!)
            when "BoardGameDetail" then BoardGameDetail.new(params[:board_game_detail].permit!)
            end

    # 3. On sauvegarde le detail
    detail.save!

    # 4. On crée l'item lié au detail et à la collection
    @item = Item.new(item_params)
    @item.collection = @collection
    @item.item_detailable = detail

    if @item.save
      redirect_to collection_path(@collection), notice: "Item ajouté !"
    else
      detail.destroy
      render :new, status: :unprocessable_entity
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
    if params[:item].present? && params[:item][:images].present?
      @item.images.attach(params[:item][:images])
    end

    new_type = params[:item][:item_type]

    if new_type != @item.item_type
      @item.item_detailable.destroy
      detail = case new_type
              when "BookDetail"      then BookDetail.new(params[:book_detail].permit!)
              when "VideoGameDetail" then VideoGameDetail.new(params[:video_game_detail].permit!)
              when "MovieDetail"     then MovieDetail.new(params[:movie_detail].permit!)
              when "MusicDetail"     then MusicDetail.new(params[:music_detail].permit!)
              when "FigurineDetail"  then FigurineDetail.new(params[:figurine_detail].permit!)
              when "TcgDetail"       then TcgDetail.new(params[:tcg_detail].permit!)
              when "BoardGameDetail" then BoardGameDetail.new(params[:board_game_detail].permit!)
              end
      detail.save!
      @item.item_detailable = detail
    else
      detail_params = params[new_type.underscore.to_sym]
      @item.item_detailable.update(detail_params.permit!) if detail_params
    end

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

  def item_params
    params.require(:item).permit(:title, :description, :acquired_at, :condition, :barcode, :item_type)
  end

  def set_collection
    @collection = Collection.find(params[:collection_id])
  end

  def set_item
    @item = @collection.items.find(params[:id])
  end

end
