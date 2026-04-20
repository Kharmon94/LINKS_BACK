# frozen_string_literal: true

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" },
                      skip: %i[sessions registrations passwords confirmations unlocks]

  namespace :api, defaults: { format: :json } do
    post "links/create-with-account", to: "v1/public_links#create_with_account"
    post "auth/magic-link", to: "v1/auth#magic_link"
    post "auth/verify", to: "v1/auth#verify"
    get "auth/session", to: "v1/auth#session"
    delete "auth/logout", to: "v1/auth#logout"

    namespace :v1 do
      post "auth/sign_in", to: "sessions#create"
      post "auth/sign_up", to: "registrations#create"
      get "auth/me", to: "sessions#me"
      resources :links, only: %i[index show create update destroy]
      get "plans", to: "plans#index"
      post "contact", to: "contacts#create"
      post "checkout/create_session", to: "checkout#create_session"
      post "portal/create_session", to: "portal#create_session"
      post "webhooks/stripe", to: "stripe_webhooks#create"
      post "cron/trial_reminders", to: "cron#trial_reminders"
      post "push/subscribe", to: "push_subscriptions#create"
      delete "push/unsubscribe", to: "push_subscriptions#destroy"

      namespace :admin do
        resources :users, only: %i[index show update]
      end
    end
  end

  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development? && defined?(LetterOpenerWeb)
end
