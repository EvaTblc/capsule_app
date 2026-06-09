Rails.application.routes.draw do
  devise_for :users, controllers: {
    omniauth_callbacks: "users/omniauth_callbacks"
    }
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "pages#home"

  resources :collections do
    resources :items
  end

    resources :items, only: [] do
      member do
        post :estimate
      end
    end

  namespace :api do
    get "search/game", to: "search#game"
    get "search/game_detail/:id", to: "search#game_detail"
    get "search/search_game"
    get "search/book", to: "search#book"
    get "search/movie", to: "search#movie"
    get "search/movie_detail/:id", to: "search#movie_detail"
    get "search/music", to: "search#music"
    get "search/music_detail/:id", to: "search#music_detail"
    get "search/game_barcode"
    get "search/game_barcode"
  end

  resources :notes, only: [:index, :show, :new, :create, :edit, :update, :destroy]
  resources :events, only: [:show, :new, :create, :edit, :update, :destroy]

  get "profile", to: "pages#profile"
  get "invite/:token", to: "invites#join", as: "invite"
  get "offline", to: "pages#offline"
  post "/items/identify", to: "items#identify"
  get "profile/address/edit", to: "pages#edit_address", as: "edit_address"
  patch "profile/address", to: "pages#update_address", as: "update_address"
end
