# Adhésions à une collection : le propriétaire retire un membre, un membre peut quitter la collection
class MembershipsController < ApplicationController
  before_action :authenticate_user!

  def destroy
    collection = current_user.collections.find(params[:collection_id])
    membership = collection.user_collections.find(params[:id])
    leaving = membership.user_id == current_user.id

    if membership.role == "owner"
      redirect_to collection, alert: "Le propriétaire ne peut pas quitter sa collection ni en être retiré."
    elsif leaving
      membership.destroy
      redirect_to collections_path, notice: "Tu as quitté la collection #{collection.title}."
    elsif collection.owner?(current_user)
      membership.destroy
      redirect_to collection, notice: "#{membership.user.email} n'a plus accès à la collection."
    else
      redirect_to collection, alert: "Action réservée au propriétaire."
    end
  end
end
