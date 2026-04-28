class PagesController < ApplicationController

  def home
    if user_signed_in?
      redirect_to collections_path
    end
  end

  def profile
    @collections_owned = current_user.user_collections.where(role: "owner").includes(:collection).map(&:collection)
    @collections_shared = current_user.user_collections.where(role: "member").includes(:collection).map(&:collection)
  end
end
