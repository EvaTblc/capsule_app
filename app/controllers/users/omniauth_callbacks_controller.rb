class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user.persisted?
      sign_in_and_redirect @user, remember_me: true
      if @user.just_linked_to_google
        flash[:notice] = "Ton compte est maintenant relié à Google. Pour te reconnecter avec un mot de passe, " \
                         "utilise « Mot de passe oublié »."
      elsif is_navigational_format?
        set_flash_message(:notice, :success, kind: "Google")
      end
    else
      session["devise.google_data"] = request.env["omniauth.auth"].except("extra")
      redirect_to new_user_registration_url, alert: @user.errors.full_messages.join("\n")
    end
  end

  def failure
    redirect_to root_path, alert: "Authentification échouée."
  end
end
