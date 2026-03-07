Rails.application.routes.draw do
  devise_for :users
  root "home#index"

  resources :books,       only: [:index, :new, :create, :show] do
    member { post :report }
  end
  resources :locations,   only: [:index, :new, :create]
  resources :labels,      only: [:index, :new, :create, :show, :edit, :update]
  resources :finds,       only: [:index, :new, :create]
  resources :profiles,    only: [:show], param: :username
  resources :friendships, only: [:create, :destroy, :index]

  get  '/friendships/requests',    to: 'friendships#requests',   as: :friendship_requests
  patch '/friendships/:id/accept', to: 'friendships#accept',     as: :accept_friendship

  get '/finds/scan/:qr_token', to: 'finds#scan', as: :scan_find

  namespace :api do
    resources :labels, only: [:index]
    get 'stats', to: 'stats#index'
  end

  get '/map',         to: 'map#index',         as: :map
  get '/leaderboard', to: 'leaderboard#index', as: :leaderboard

  namespace :admin do
    root to: 'dashboard#index'
    resources :users,     only: [:index, :show, :edit, :update, :destroy]
    resources :books,     only: [:index, :show, :edit, :update, :destroy] do
      member do
        patch :approve
        patch :reject
        patch :flag
        patch :unflag
      end
    end
    resources :labels,    only: [:index, :show, :update, :destroy]
    resources :locations, only: [:index, :show, :edit, :update, :destroy] do
      member { patch :set_status }
    end
    resources :badges,    only: [:index, :new, :create, :edit, :update, :destroy] do
      resources :user_badges, only: [:create, :destroy]
    end
  end
end