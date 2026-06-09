class NotesController < ApplicationController
  before_action :set_notes, only: [:show, :edit, :update, :destroy]
  def index
    @notes = Note.all
    @events = Event.all

    @markers = @events.geocoded.map do |event|
      {
        lat: event.latitude,
        lng: event.longitude
      }
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
