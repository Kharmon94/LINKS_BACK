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
      patch "account/active_workspace", to: "account#active_workspace"
      resources :custom_domains, only: %i[index create update destroy] do
        member do
          post :verify
        end
      end
      resources :workspaces, only: %i[index show create update destroy] do
        member do
          post "members", to: "workspaces#add_member"
          delete "members/:user_id", to: "workspaces#remove_member"
        end
      end
      resource :team, only: [:show] do
        post :invitations, to: "teams#create_invitation"
        get "members/:member_id", to: "teams#show_member"
        patch "members/:member_id", to: "teams#update_member"
        delete "members/:member_id", to: "teams#destroy_member"
        get "members/:member_id/clicks", to: "teams#member_clicks"
      end
      get "team_invitations/:token", to: "team_invitations#show"
      post "team_invitations/:token/accept", to: "team_invitations#accept"
      resources :links, only: %i[index show create update destroy] do
        member do
          get :clicks
          get :analytics, to: "analytics#link_analytics"
        end
      end
      resources :campaigns, only: %i[index show create update destroy] do
        member do
          post :assign_links
          post :unassign_links
          get :analytics, to: "analytics#campaign_analytics"
        end
      end
      get "analytics/overview", to: "analytics#overview"
      get "analytics/links/:link_id", to: "analytics#link_analytics"
      get "plans", to: "plans#index"
      post "contact", to: "contacts#create"
      post "checkout/create_session", to: "checkout#create_session"
      post "portal/create_session", to: "portal#create_session"
      patch "account", to: "account#update"
      patch "account/active_workspace", to: "account#active_workspace"
      patch "account/password", to: "account#update_password"
      get "account/notification_preferences", to: "account#notification_preferences"
      patch "account/notification_preferences", to: "account#update_notification_preferences"
      get "team", to: "teams#show"
      post "team/invitations", to: "teams#create_invitation"
      get "team/members/:member_id", to: "teams#show_member"
      get "team/members/:member_id/clicks", to: "teams#member_clicks"
      patch "team/members/:member_id", to: "teams#update_member"
      delete "team/members/:member_id", to: "teams#destroy_member"

      resources :workspaces, only: %i[index show create update destroy] do
        member do
          post "members", to: "workspaces#add_member"
          delete "members/:user_id", to: "workspaces#remove_member"
        end
      end

      resources :custom_domains, only: %i[index create update destroy] do
        member do
          post :verify
        end
      end

      get "team_invitations/:token", to: "team_invitations#show"
      post "team_invitations/:token/accept", to: "team_invitations#accept"

      post "webhooks/stripe", to: "stripe_webhooks#create"
      post "cron/trial_reminders", to: "cron#trial_reminders"
      post "cron/weekly_reports", to: "cron#weekly_reports"
      post "cron/link_milestones", to: "cron#link_milestones"
      post "push/subscribe", to: "push_subscriptions#create"
      delete "push/unsubscribe", to: "push_subscriptions#destroy"
      post "pwa/confirm_install", to: "pwa#confirm_install"
      post "pwa/reset_install", to: "pwa#reset_install"

      namespace :admin do
        get "health", to: "health#show"
        get "dashboard", to: "dashboard#show"
        get "billing/overview", to: "billing#overview"
        get "billing/stripe_mode", to: "billing#stripe_mode"
        patch "billing/stripe_mode", to: "billing#update_stripe_mode"
        get "billing/lookup", to: "billing#lookup"
        post "billing/portal_session", to: "billing#portal_session"
        post "billing/cancel_subscription", to: "billing#cancel_subscription"
        resources :teams, only: %i[index show]
        resources :users, only: %i[index show update] do
          resources :feature_flags, only: %i[index update], param: :key, controller: "user_feature_flags"
        end
        resources :links, only: %i[index show destroy]
        resources :feature_flags, only: %i[index update], param: :key
        resources :campaigns, only: %i[index destroy]
        resources :workspaces, only: %i[index destroy]
        resources :custom_domains, only: %i[index destroy]
        resources :web_push_subscriptions, only: %i[index destroy]
      end
    end
  end

  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development? && defined?(LetterOpenerWeb)

  get "/:short_code", to: "redirects#show",
                     constraints: { short_code: /[a-z0-9]{4,32}/ },
                     format: false
end
