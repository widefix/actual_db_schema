# frozen_string_literal: true

ActualDbSchema::Engine.routes.draw do
  resources :migrations, only: %i[index show] do
    member do
      post :rollback
      post :migrate
    end
  end
  resources :phantom_migrations, only: %i[index show] do
    member do
      post :rollback
    end
    collection do
      post :rollback_all
    end
  end

  get "schema", to: "schema#index", as: :schema
end
