# frozen_string_literal: true

module ActualDbSchema
  # Controller to display the list of phantom migrations for each database connection.
  class PhantomMigrationsController < ActionController::Base
    def index; end

    def show
      render file: "#{Rails.root}/public/404.html", layout: false, status: :not_found unless phantom_migration
    end

    def rollback
      ActualDbSchema::Migration.instance.rollback(params[:id], params[:database])
      redirect_to phantom_migrations_path
    end

    def rollback_all
      ActualDbSchema::Migration.instance.rollback_all
      redirect_to phantom_migrations_path
    end

    private

    helper_method def phantom_migrations
      @phantom_migrations ||= ActualDbSchema::Migration.instance.all_phantom
    end

    helper_method def phantom_migration
      @phantom_migration ||= ActualDbSchema::Migration.instance.find(params[:id], params[:database])
    end
  end
end
