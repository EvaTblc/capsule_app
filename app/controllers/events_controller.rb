class EventsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_event, only: [:show, :edit, :update, :destroy, :share]
  def show
  end

  def list_events
    alert = import_nearby_events

    @events = Event.nearby_for(current_user)
    @markers = @events.geocoded.map do |event|
      {
        lat: event.latitude.to_f,
        lng: event.longitude.to_f,
        info_window_html: render_to_string(partial: "notes/info_window", locals: { event: event }, formats: [:html])
      }
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "events-section",
          partial: "notes/events_section",
          locals: { events: @events, markers: @markers, alert: alert }
        )
      end
    end
  end

  def share
    friend = current_user.accepted_friends.find(params[:friend_id])

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
          html: helpers.tag.p("Envoyé !", class: "text-xs text-green-500 font-semibold")
        )
      end
      format.html { redirect_to event_path(@event), notice: "Événement partagé !" }
    end
  end

  def create
    @event = Event.new(events_params)
    @event.user = current_user
    if @event.save
      redirect_to event_path(@event)
    else
      # Le formulaire d'événement vit dans notes/new (pas de vue events/new)
      @note = Note.new
      render "notes/new", status: :unprocessable_entity
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

  # Importe les brocantes des 7 prochains jours du département de l'utilisateur.
  # Renvoie un message d'alerte si l'import n'a pas pu se faire, nil sinon.
  def import_nearby_events
    return "Ajoute ton adresse dans ton profil pour trouver des événements." if current_user.address.blank?

    postal_code = user_postal_code
    return "Impossible de trouver ton département à partir de ton adresse." if postal_code.blank?

    department = Scraper.department_for(postal_code)
    return "La recherche de brocantes n'est disponible qu'en France métropolitaine pour le moment." if department.nil?

    # Brocabrac n'est scrapé qu'une fois par heure et par département, quel que soit le nombre d'utilisateurs
    infos = Rails.cache.fetch(["brocabrac", department], expires_in: 1.hour) { Scraper.call(department) }

    infos.select { |info| info[:date].present? && info[:date].between?(Date.today, 7.days.from_now.to_date) }.each do |info|
      Event.find_or_create_by(url: info[:url], user: current_user) do |e|
        e.title = info[:title]
        e.date = info[:date]
        e.address = "#{info[:address]}, #{info[:city]}"
        e.latitude = info[:latitude]
        e.longitude = info[:longitude]
      end
    end
    nil
  rescue Scraper::NetworkError, Scraper::ParseError => e
    Rails.logger.error("[list_events] #{e.class}: #{e.message}")
    "La recherche d'événements est indisponible pour le moment, réessaie plus tard."
  end

  # Le code postal ne change qu'avec l'adresse : on le met en cache pour éviter un appel Mapbox à chaque clic
  def user_postal_code
    Rails.cache.fetch(["user_postal_code", current_user.address], expires_in: 30.days, skip_nil: true) do
      Geocoder.search(current_user.address).first&.postal_code
    end
  end

  def events_params
    params.require(:event).permit(:address, :comment, :date, :latitude, :longitude, :reminder, :title, :url)
  end

  def set_event
    @event = current_user.events.find(params[:id])
  end
end
