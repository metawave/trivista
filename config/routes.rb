Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  get "login" => "sessions#new"
  get "auth/openid_connect/callback" => "sessions#create"
  get "auth/failure" => "sessions#failure"
  delete "logout" => "sessions#destroy"

  namespace :api do
    resources :scans, only: :create
  end

  resources :projects, only: %i[show edit update destroy]
  resources :repos, only: %i[show update destroy]
  resources :branches, only: %i[show destroy]
  resources :scans, only: %i[show destroy]
  resources :service_accounts, only: %i[index new create show] do
    resources :upload_tokens, only: :create, shallow: true
  end
  resources :upload_tokens, only: :destroy
  resources :active_sessions, only: %i[index destroy], path: "sessions"

  namespace :admin do
    resources :users, only: :index do
      member do
        patch :deactivate
        patch :reactivate
        patch :end_sessions
      end
    end
  end

  # Living styleguide of docs/design-system.md; local environments only, it needs no login.
  get "design" => "design#show" if Rails.env.local?

  root "projects#index"
end
