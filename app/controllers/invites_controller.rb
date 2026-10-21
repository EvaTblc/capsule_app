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

    # create_or_find_by s'appuie sur l'index unique : un double clic ne crée pas deux adhésions
    UserCollection.create_or_find_by(user: current_user, collection: @collection) { |membership| membership.role = "member" }
    redirect_to @collection, notice: "Tu as rejoint la collection #{@collection.title} !"
  end
end
