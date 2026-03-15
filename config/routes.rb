Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :pro do
      resources :checkout_sessions, only: :create

      namespace :webhooks do
        post :creem, to: "creem#create"
      end

      namespace :claims do
        post :redeem, to: "redemptions#create"
      end

      scope :licenses do
        post :activate, to: "licenses#activate"
        get :status, to: "licenses#status"
        post :deactivate, to: "licenses#deactivate"
      end
    end

    namespace :support do
      resources :licenses, only: :show, param: :reference do
        member do
          get :activations
          post :release
          post :resend_claim_link
        end
      end

      post "purchases/resync", to: "purchases#resync"
    end
  end
end
