class PagesController < ApplicationController
  before_action :authenticate_user!, except: [ :home, :offline, :credits ]
  def home
    if user_signed_in?
      redirect_to collections_path
    end
  end

  def profile
    @collections_owned = current_user.user_collections
      .where(role: "owner")
      .includes(collection: [ :cover_image_attachment, items: :item_detailable ])
      .map(&:collection)

    @collections_shared = current_user.user_collections
      .where(role: "member")
      .includes(collection: [ :cover_image_attachment, items: :item_detailable ])
      .map(&:collection)

    @friends = current_user.accepted_friends
    # Amitié de chaque ami (bouton « Retirer »), chargées en une requête au lieu d'une par ami
    @friendships_by_friend = Friendship.accepted.where(requester: current_user)
      .or(Friendship.accepted.where(receiver: current_user))
      .index_by { |friendship| friendship.requester_id == current_user.id ? friendship.receiver_id : friendship.requester_id }
    @pending_friendships = current_user.received_friendships.where(status: "pending")
    @sent_friendships = current_user.sent_friendships.where(status: "pending").includes(:receiver)
  end

  def edit_address
  end

  def update_address
    if current_user.update(address_params)
      redirect_to profile_path
    else
      render :edit_address, status: :unprocessable_entity
    end
  end

  # Attribution des sources de données, exigée par leurs conditions d'utilisation
  def credits
  end

  def offline
    render layout: false
  end
  private

  def address_params
    params.require(:user).permit(:address)
  end
end
