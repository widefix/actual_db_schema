# frozen_string_literal: true

ActualDbSchema::Engine.routes.draw do
  root to: "migrations#index"
  resources :migrations, only: %i[index show] do
    member do
      post :rollback
    end
  end
end
