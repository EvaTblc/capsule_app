class EventsController < ApplicationController
  before_action :set_event, only: [:show, :edit, :update, :destroy, :share]
  def show
  end

  def list_events
    results = Geocoder.search(current_user.address)
    postal_code = results.first&.postal_code
    department = postal_code&.first(2)
    infos = Scraper.call(department)

    infos.select { |info| info[:date].present? && info[:date] <= 7.days.from_now.to_date && info[:date] >= Date.today }.each do |info|
      Event.find_or_create_by(url: info[:url], user: current_user) do |e|
        e.title = info[:title]
        e.date = info[:date]
        e.address = "#{info[:address]}, #{info[:city]}"
        e.latitude = info[:latitude]
        e.longitude = info[:longitude]
        e.url = info[:url]
      end
    end

    @events = Event.where(user: current_user).near(current_user.address, 50)
    @markers = @events.geocoded.map { |e| { lat: e.latitude.to_f, lng: e.longitude.to_f } }

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "events-section",
          partial: "notes/events_section",
          locals: { events: @events, markers: @markers }
        )
      end
    end
  end

  def share
    friend = User.find(params[:friend_id])

    Event.create!(
      user: friend,
      sender: current_user,
      title: @event.title,
      date: @event.date,
      address: @event.address,
      latitude: @event.latitude,
      longitude: @event.longitude,
      url: @event.url,
      reminder: @event.reminder
    )

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "share-event-#{@event.id}",
          html: '<p class="text-xs text-green-500 font-semibold">Envoyé !</p>'.html_safe
        )
      end
      format.html { redirect_to event_path(@event), notice: "Événement partagé !" }
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
    @note = Note.new
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
