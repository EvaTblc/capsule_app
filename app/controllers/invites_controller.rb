class InvitesController < ApplicationController
  before_action :authenticate_user!

  def join
    @collection = Collection.find_by(invite_token: params[:token])

    if @collection.nil?
      redirect_to collections_path, alert: "Lien invalide."
      return
    end

    if current_user.collections.include?(@collection)
      redirect_to @collection, notice: "Tu es déjà membre de cette collection."
      return
    end

    UserCollection.create(user: current_user, collection: @collection, role: "member")
    redirect_to @collection, notice: "Tu as rejoint la collection #{@collection.title} !"
  end
end
