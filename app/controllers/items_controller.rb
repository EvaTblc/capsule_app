class ItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_collection, except: [:estimate, :identify]
  before_action :set_item, only: [:show, :edit, :update, :destroy]

  def show
  end

  def new
    @item = Item.new
  end

  def create
    item_type = params[:item][:item_type]

    detail_params = case item_type
    when "VideoGameDetail"
      p = params[:video_game_detail].permit!.to_h
      # Traduction du summary uniquement pour les jeux vidéo
      if p["description"].present?
        p["description"] = TranslationService.translate_batch([p["description"]]).first
      end
      p
    when "BookDetail"
      p = params[:book_detail].permit!.to_h
        if p["description"].blank?
          p["description"] = BookDescriptionService.generate(
            title: params[:item][:title],
            author: p["author"],
            isbn: p["isbn"]
          )
        end
        p
    when "MovieDetail"     then params[:movie_detail].permit!.to_h
    when "MusicDetail"     then params[:music_detail].permit!.to_h
    when "FigurineDetail"  then params[:figurine_detail].permit!.to_h
    when "TcgDetail"       then params[:tcg_detail].permit!.to_h
    when "BoardGameDetail" then params[:board_game_detail].permit!.to_h
    end

    detail = case item_type
    when "BookDetail"      then BookDetail.new(detail_params)
    when "VideoGameDetail" then VideoGameDetail.new(detail_params)
    when "MovieDetail"     then MovieDetail.new(detail_params)
    when "MusicDetail"     then MusicDetail.new(detail_params)
    when "FigurineDetail"  then FigurineDetail.new(detail_params)
    when "TcgDetail"       then TcgDetail.new(detail_params)
    when "BoardGameDetail" then BoardGameDetail.new(detail_params)
    end

    detail.save!

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
      @item.item_detailable&.destroy
      detail = case new_type
              when "BookDetail"
                then BookDetail.new(params[:book_detail].permit!)
                p = params[:book_detail].permit!.to_h
                if p["description"].blank?
                  p["description"] = BookDescriptionService.generate(
                    title: params[:item][:title],
                    author: p["author"],
                    isbn: p["isbn"]
                  )
                end
                BookDetail.new(p)
              when "VideoGameDetail"
              p = params[:video_game_detail].permit!.to_h
              p["description"] = TranslationService.translate_batch([p["description"]]).first if p["description"].present?
              VideoGameDetail.new(p)
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

      if detail_params && new_type == "VideoGameDetail" && detail_params["description"].present?
        detail_params["description"] = TranslationService.translate_batch([detail_params["description"]]).first
      end

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

  def estimate
    @item = Item.find(params[:id])
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
    @collection = Collection.find(params[:collection_id])
  end

  def set_item
    @item = @collection.items.find(params[:id])
  end

end
