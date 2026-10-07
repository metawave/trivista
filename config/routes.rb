Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  get "login" => "sessions#new"
  get "auth/openid_connect/callback" => "sessions#create"
  get "auth/failure" => "sessions#failure"
  delete "logout" => "sessions#destroy"

  namespace :api do
    resources :scans, only: :create
  end

  resources :scans, only: :show

  root "projects#index"
end
