# frozen_string_literal: true

Audioroom::Engine.routes.draw do
  resources :rooms do
    member do
      post :join
      post :heartbeat
      delete :leave
      get :participants
      post :toggle_mute
      post :mute_participant
      post :hard_mute
      post :hard_unmute
      delete :kick
      post :unkick
      post :ban
      delete :ban, action: :unban
      post :raise_hand
      delete :raise_hand, action: :lower_hand
      patch :archive
      patch :unarchive
    end

    resources :memberships, controller: "room_memberships", only: %i[index create update destroy]
  end

  scope "/rooms/:room_id" do
    post   "follow", to: "room_follows#create"
    delete "follow", to: "room_follows#destroy"
    post   "livestream/start",  to: "livestream#start"
    delete "livestream/stop",   to: "livestream#stop"
    patch  "livestream/layout", to: "livestream#layout"
  end

  get "invite/:token", to: "room_invite#show"

  get  "broadcast/:slug", to: "broadcast#show", as: :broadcast
  post "webhook",         to: "webhook#receive"
  get  "contacts" => "contacts#index"
end

Discourse::Application.routes.draw do
  scope "/admin/plugins/audioroom", constraints: AdminConstraint.new do
    scope format: false do
      get "/audioroom-rooms" => "audioroom/admin#index"
      get "/audioroom-rooms/new" => "audioroom/admin#new"
      get "/audioroom-rooms/:id" => "audioroom/admin#edit"
      get "/audioroom-dashboard" => "audioroom/admin#index"
      get "/audioroom-kicked" => "audioroom/admin#index"
      get "/audioroom-banned" => "audioroom/admin#index"
      get "/audioroom-danger-zone" => "audioroom/admin#index"
    end

    scope format: :json do
      get "/rooms" => "audioroom/admin_rooms#index"
      get "/rooms/:id" => "audioroom/admin_rooms#show"
      post "/rooms" => "audioroom/admin_rooms#create"
      put "/rooms/:id" => "audioroom/admin_rooms#update"
      delete "/rooms/:id" => "audioroom/admin_rooms#destroy"
      patch "/rooms/:id/archive" => "audioroom/admin_rooms#archive"
      patch "/rooms/:id/unarchive" => "audioroom/admin_rooms#unarchive"

      get "/stats/overview" => "audioroom/admin_stats#overview"
      get "/stats/rooms" => "audioroom/admin_stats#rooms"
      get "/stats/users" => "audioroom/admin_stats#users"

      get  "/kicked" => "audioroom/admin_kicked#index"
      post "/kicked/:room_id/unkick" => "audioroom/admin_kicked#unkick"

      get    "/banned" => "audioroom/admin_banned#index"
      post   "/banned/:room_id/unban" => "audioroom/admin_banned#unban"

      post "/reset" => "audioroom/admin#reset"
    end
  end
end
