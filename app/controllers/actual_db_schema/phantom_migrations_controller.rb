# frozen_string_literal: true

module ActualDbSchema
  # Controller to display the list of phantom migrations for each database connection.
  class PhantomMigrationsController < ActionController::Base
    def index; end

    def show
      render file: "#{Rails.root}/public/404.html", layout: false, status: :not_found unless phantom_migration
    end

    def rollback
      ActualDbSchema::Migration.rollback(params[:id], params[:database])
      redirect_to phantom_migrations_path
    end

    private

    helper_method def phantom_migrations
      @phantom_migrations ||= ActualDbSchema::Migration.all
    end

    helper_method def phantom_migration
      @phantom_migration ||= ActualDbSchema::Migration.find(params[:id], params[:database])
    end
  end
end
