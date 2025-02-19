# frozen_string_literal: true

module ActualDbSchema
  # Controller to display the list of migrations for each database connection.
  class MigrationsController < ActionController::Base
    protect_from_forgery with: :exception
    skip_before_action :verify_authenticity_token

    def index; end

    def show
      render file: "#{Rails.root}/public/404.html", layout: false, status: :not_found unless migration
    end

    def rollback
      handle_rollback(params[:id], params[:database])
      redirect_to migrations_path
    end

    def migrate
      handle_migrate(params[:id], params[:database])
      redirect_to migrations_path
    end

    private

    def handle_rollback(id, database)
      ActualDbSchema::Migration.instance.rollback(id, database)
      flash[:notice] = "Migration #{id} was successfully rolled back."
    rescue StandardError => e
      flash[:alert] = e.message
    end

    def handle_migrate(id, database)
      ActualDbSchema::Migration.instance.migrate(id, database)
      flash[:notice] = "Migration #{id} was successfully migrated."
    rescue StandardError => e
      flash[:alert] = e.message
    end

    helper_method def migrations
      @migrations ||= ActualDbSchema::Migration.instance.all
      query = params[:query].to_s.strip.downcase

      return @migrations if query.blank?

      @migrations.select do |migration|
        file_name_matches = migration[:filename].include?(query)
        content_matches = begin
          File.read(migration[:filename]).downcase.include?(query)
        rescue StandardError
          false
        end

        file_name_matches || content_matches
      end
    end

    helper_method def migration
      @migration ||= ActualDbSchema::Migration.instance.find(params[:id], params[:database])
    end
  end
end
