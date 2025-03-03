# frozen_string_literal: true

ActualDbSchema::Engine.routes.draw do
  scope ActualDbSchema.config[:ui_namespace] do
    resources :phantom_migrations, only: %i[index show] do
      member do
        post :rollback
      end
      collection do
        post :rollback_all
      end
    end

    resources :broken_versions, only: %i[index] do
      member do
        post :delete
      end
      collection do
        post :delete_all
      end
    end

    get "schema", to: "schema#index", as: :schema
  end

  resources :migrations, only: %i[index show] do
    member do
      post :rollback
      post :migrate
    end
  end
end
