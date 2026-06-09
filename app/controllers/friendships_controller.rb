class FriendshipsController < ApplicationController
  before_action :set_friendship, only: [:accept, :reject, :destroy]

  def create
    receiver = User.find_by(email: params[:receiver_email])
    if receiver.nil?
      redirect_to profile_path, alert: "Utilisateur introuvable."
    elsif receiver == current_user
      redirect_to profile_path, alert: "Tu ne peux pas t'ajouter toi-même."
    else
      @friendship = Friendship.new(requester: current_user, receiver: receiver, status: "pending")
      if @friendship.save
        redirect_to profile_path, notice: "Demande envoyée !"
      else
        redirect_to profile_path, alert: "Demande déjà envoyée."
      end
    end
  end

  def accept
    @friendship.accepted!
    redirect_to profile_path, notice: "Ami ajouté !"
  end

  def reject
    @friendship.rejected!
    redirect_to profile_path, notice: "Demande refusée."
  end

  def destroy
    @friendship.destroy
    redirect_to profile_path, notice: "Ami supprimé."
  end

  private

  def set_friendship
    @friendship = Friendship.find(params[:id])
  end
end
