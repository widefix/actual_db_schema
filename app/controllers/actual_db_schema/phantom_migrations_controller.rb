# frozen_string_literal: true

module ActualDbSchema
  # Controller to display the list of phantom migrations for each database connection.
  class PhantomMigrationsController < ActionController::Base
    def index; end

    def show
      render file: "#{Rails.root}/public/404.html", layout: false, status: :not_found unless phantom_migration
    end

    def rollback
      handle_rollback(params[:id], params[:database])
      redirect_to phantom_migrations_path
    end

    def rollback_all
      handle_rollback_all
      redirect_to phantom_migrations_path
    end

    private

    def handle_rollback(id, database)
      ActualDbSchema::Migration.instance.rollback(id, database)
      flash[:notice] = "Migration #{id} was successfully rolled back."
    rescue StandardError => e
      flash[:alert] = e.message
    end

    def handle_rollback_all
      ActualDbSchema::Migration.instance.rollback_all
      flash[:notice] = "Migrations was successfully rolled back."
    rescue StandardError => e
      flash[:alert] = e.message
    end

    helper_method def phantom_migrations
      @phantom_migrations ||= ActualDbSchema::Migration.instance.all_phantom
    end

    helper_method def phantom_migration
      @phantom_migration ||= ActualDbSchema::Migration.instance.find(params[:id], params[:database])
    end
  end
end
