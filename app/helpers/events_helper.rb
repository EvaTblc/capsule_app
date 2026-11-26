module EventsHelper
  # Quand a lieu l'événement, par rapport à aujourd'hui : « aujourd'hui », « demain », « dans 5 jours », « hier », « il y a 3 jours »
  def event_countdown(date)
    days = (date - Date.current).to_i
    case days
    when 0 then "aujourd'hui"
    when 1 then "demain"
    when -1 then "hier"
    else days.positive? ? "dans #{days} jours" : "il y a #{-days} jours"
    end
  end
end
