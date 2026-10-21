class FriendshipsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_friendship, only: [:destroy]
  before_action :set_received_friendship, only: [:accept, :reject]

  def create
    receiver = User.find_by(email: params[:receiver_email])
    if receiver.nil?
      redirect_to profile_path, alert: "Utilisateur introuvable."
    elsif receiver == current_user
      redirect_to profile_path, alert: "Tu ne peux pas t'ajouter toi-même."
    else
      existing = Friendship.between(current_user, receiver).first

      if existing.nil?
        Friendship.create!(requester: current_user, receiver: receiver, status: "pending")
        redirect_to profile_path, notice: "Demande envoyée !"
      elsif existing.accepted?
        redirect_to profile_path, alert: "Vous êtes déjà amis."
      elsif existing.receiver == current_user
        # L'autre m'avait déjà demandé en ami : demander à mon tour revient à accepter
        existing.accepted!
        redirect_to profile_path, notice: "Vous êtes maintenant amis !"
      else
        # Demande en attente ou refusée : même message, pour ne pas révéler un refus
        redirect_to profile_path, alert: "Demande déjà envoyée."
      end
    end
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    # Deux demandes simultanées : l'index unique a bloqué la seconde
    redirect_to profile_path, alert: "Demande déjà envoyée."
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

  def set_received_friendship
    @friendship = current_user.received_friendships.find(params[:id])
  end

  def set_friendship
    @friendship = Friendship.where(requester: current_user)
                            .or(Friendship.where(receiver: current_user))
                            .find(params[:id])
  end
end
