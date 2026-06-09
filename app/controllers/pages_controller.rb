class PagesController < ApplicationController

  def home
    if user_signed_in?
      redirect_to collections_path
    end
  end

  def profile
    @collections_owned = current_user.user_collections
      .where(role: "owner")
      .includes(collection: [:items, :cover_image_attachment])
      .map(&:collection)

    @collections_shared = current_user.user_collections
      .where(role: "member")
      .includes(collection: [:items, :cover_image_attachment])
      .map(&:collection)

    @friends = current_user.all_friends
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

  def offline
    render layout: false
  end
  private

  def address_params
    params.require(:user).permit(:address)
  end

end
