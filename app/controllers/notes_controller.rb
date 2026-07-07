class NotesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_notes, only: [:show, :edit, :update, :destroy, :share]
  def index
    @notes = Note.all
    if current_user.address != nil
      @events = Event.near(current_user.address, 50)

      @markers = @events.geocoded.map do |event|
        {
          lat: event.latitude.to_f,
          lng: event.longitude.to_f
        }
      end
    else
      @events = Event.where(user: current_user)
    end
  end

  def share
    friend = User.find(params[:friend_id])

    Note.create!(
      user: friend,
      sender: current_user,
      title: @note.title,
      comment: @note.comment,
      reminder: @note.reminder
    )

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "share-note-#{@note.id}",
          html: '<p class="text-xs text-green-500 font-semibold">Envoyé !</p>'
        )
      end
      format.html { redirect_to note_path(@note), notice: "Note partagée !" }
    end
  end

  def show
  end

  def new
    @note = Note.new
    @event = Event.new
  end

  def create
    @note = Note.new(notes_params)
    @note.user = current_user
    if @note.save!
      redirect_to note_path(@note)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @note.update(notes_params)
      redirect_to note_path(@note)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    redirect_to notes_path, status: :see_other if @note.destroy
  end

  private

  def notes_params
    params.require(:note).permit(:title, :comment, :reminder)
  end

  def set_notes
    @note = Note.find(params[:id])
  end
end
