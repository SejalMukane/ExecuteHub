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

      resources :projects, only: [:index, :show, :create, :update, :destroy] do
        resources :test_runs, only: [:create]
      end

      resources :test_runs, only: [:index, :show] do
        collection do
          get "suites", to: "test_runs#suites"
        end
      end

      resources :jobs, only: [:show] do
        member do
          get "logs"
          get "artifacts"
        end
      end

      resources :artifacts, only: [] do
        member do
          get "file"
        end
      end

      get "queue", to: "queue#show"

      get    "github/oauth/start",    to: "github_auth#start"
      get    "github/oauth/callback", to: "github_auth#callback"
      get    "github/status",         to: "github_auth#status"
      delete "github/disconnect",     to: "github_auth#disconnect"

      get    "github/repositories",                  to: "github_repositories#index"
      post   "github/repositories",                  to: "github_repositories#connect"
      delete "github/repositories",                  to: "github_repositories#disconnect"
      get    "github/projects/:project_id/repository", to: "github_repositories#show"

      post "github/webhooks/:slug", to: "github_webhooks#receive"
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
