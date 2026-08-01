Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      post "register", to: "auth#register"
      post "login",    to: "auth#login"
      post "logout",   to: "auth#logout"
      get  "me",       to: "auth#me"
      put  "profile",  to: "auth#update_profile"
      patch "profile", to: "auth#update_profile"

      post   "session/start", to: "sessions#start"
      get    "session",       to: "sessions#index"
      delete "session/:id",   to: "sessions#destroy"
      get    "browser-images", to: "sessions#images"

      resources :projects, only: [:index, :show, :create, :update, :destroy]
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
