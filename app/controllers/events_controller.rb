class EventsController < ApplicationController
  before_action :set_event, only: [:show, :edit, :update, :destroy]
  def show
  end

  def list_events
    results = Geocoder.search(current_user.address)
    postal_code = results.first&.postal_code
    department = postal_code&.first(2)
    infos = Scraper.call(department)

    infos.each do |info|
      Event.create!(
      user: current_user,
      title: info[:title],
      date: info[:date],
      address: "#{info[:address]}, #{info[:city]}",
      latitude: info[:latitude],
      longitude: info[:longitude],
      url: info[:url]
    )
    end
  end

  def create
    @event = Event.new(events_params)
    @event.user = current_user
    if @event.save!
      redirect_to event_path(@event)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @event.update(events_params)
      redirect_to event_path(@event)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    redirect_to notes_path, status: :see_other if @event.destroy
  end

  private

  def events_params
    params.require(:event).permit(:address, :comment, :date, :latitude, :longitude, :reminder, :title, :url)
  end

  def set_event
    @event = Event.find(params[:id])
  end
end
