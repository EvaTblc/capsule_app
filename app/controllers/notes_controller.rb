class NotesController < ApplicationController
  def index
    @notes = Note.all
    @events = Event.all
  end

  def show
    @note = Note.find(params[:id])
  end

  def new
    @note = Note.new
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

  private

  def notes_params
    params.require(:note).permit(:title, :comment, :reminder)
  end
end
