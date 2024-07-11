# frozen_string_literal: true

module ActualDbSchema
  # Controller to display the list of migrations for each database connection.
  class MigrationsController < ActionController::Base
    def index; end

    def show
      render file: "#{Rails.root}/public/404.html", layout: false, status: :not_found unless migration
    end

    def rollback
      ActualDbSchema::Migration.rollback(params[:id], params[:database])
      redirect_to migrations_path
    end

    private

    helper_method def migrations
      @migrations ||= ActualDbSchema::Migration.all
    end

    helper_method def migration
      @migration ||= ActualDbSchema::Migration.find(params[:id], params[:database])
    end
  end
end
