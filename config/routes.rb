require "sidekiq/web"

Rails.application.routes.draw do
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" }

  get  "sign_in",  to: "sessions#new",     as: :sign_in
  delete "sign_out", to: "sessions#destroy", as: :sign_out

  resources :workspaces, only: [:new, :create, :show] do
    resources :memberships, only: [:new, :create, :destroy],
                            controller: "workspace_memberships"
    resources :apps, only: [:new, :create, :show, :edit, :update, :destroy] do
      resources :reports, only: [:create, :show, :index] do
        member do
          post :reanalyze
          post :refresh
        end
        collection do
          post :reanalyze
          post :refresh
        end
      end
    end
  end

  resources :notifications, only: [:update] do
    collection do
      patch :mark_all_read
    end
  end

  mount ActionCable.server => "/cable"

  # Sidekiq Web UI is intentionally development-only for now — mounting it
  # unconditionally would expose an unauthenticated admin UI (with job
  # retry/delete actions) in staging/production.
  # TODO: add authentication before enabling in any deployed environment
  if Rails.env.development?
    mount Sidekiq::Web => "/sidekiq"
  end

  root "dashboard#index"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
