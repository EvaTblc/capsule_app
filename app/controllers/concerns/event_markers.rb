# Repères de la carte des événements (Mon Carnet, et sa mise à jour après « Trouver des événements près de moi »)
module EventMarkers
  extend ActiveSupport::Concern

  private

  def event_markers(events)
    events.select(&:geocoded?).map do |event|
      {
        lat: event.latitude.to_f,
        lng: event.longitude.to_f,
        info_window_html: render_to_string(partial: "events/info_window", locals: { event: event }, formats: [ :html ])
      }
    end
  end
end
