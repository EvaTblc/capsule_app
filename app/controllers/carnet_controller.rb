# Mon Carnet : ce que je cherche (les souhaits de toutes mes collections) et les chineries à venir (événements)
class CarnetController < ApplicationController
  include EventMarkers
  before_action :authenticate_user!

  def show
    @events = Event.nearby_for(current_user).to_a
    @markers = event_markers(@events)
    @next_event = @events.select { |event| event.date&.>=(Date.current) }.min_by(&:date)
    @wishes_by_collection = Wish.where(collection_id: current_user.collections.select(:id)).includes(:collection)
                                .sort_by { |wish| NaturalSort.key(wish.title) }
                                .group_by(&:collection)
                                .sort_by { |collection, _| NaturalSort.key(collection.title) }
  end
end
