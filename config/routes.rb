# frozen_string_literal: true

ActualDbSchema::Engine.routes.draw do
  root to: "migrations#index"
  namespace :actual_db_schema do
    resources :migrations, only: [:index]
  end
end
