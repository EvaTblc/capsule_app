# Souhaits d'un ami, en lecture seule, groupés par collection
class FriendWishesController < ApplicationController
  before_action :authenticate_user!

  def index
    # Seulement parmi mes amis acceptés : quelqu'un d'autre donne 404
    @friend = current_user.accepted_friends.find(params[:friend_id])
    # Mêmes règles que partout (Wish.visible_to : interrupteur, collections partagées), limitées à ce qu'il a ajouté
    @wishes_by_collection = Wish.visible_to(current_user).where(author: @friend).includes(:collection)
                                .sort_by { |wish| NaturalSort.key(wish.title) }
                                .group_by(&:collection)
                                .sort_by { |collection, _| NaturalSort.key(collection.title) }
  end
end
