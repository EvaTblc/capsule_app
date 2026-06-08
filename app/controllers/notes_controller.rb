class NotesController < ApplicationController
  def index
    @notes = Note.all
    @events = Event.all
  end
end
