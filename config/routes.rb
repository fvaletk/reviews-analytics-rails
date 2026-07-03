Rails.application.routes.draw do
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" }

  get  "sign_in",  to: "sessions#new",     as: :sign_in
  delete "sign_out", to: "sessions#destroy", as: :sign_out

  resources :workspaces, only: [:new, :create, :show] do
    resources :memberships, only: [:new, :create, :destroy],
                            controller: "workspace_memberships"
    resources :apps, only: [:new, :create, :show] do
      resources :reports, only: [:create, :show]
    end
  end

  mount ActionCable.server => "/cable"

  root "dashboard#index"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
