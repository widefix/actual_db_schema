# frozen_string_literal: true

ActualDbSchema::Engine.routes.draw do
  resources :migrations, only: %i[index show]
  resources :phantom_migrations, only: %i[index show] do
    member do
      post :rollback
    end
  end
end
