# frozen_string_literal: true

module ActualDbSchema
  # Controller for managing broken migration versions.
  class BrokenVersionsController < ActionController::Base
    protect_from_forgery with: :exception
    skip_before_action :verify_authenticity_token

    def index; end

    def delete
      handle_delete(params[:id], params[:database])
      redirect_to broken_versions_path
    end

    def delete_all
      handle_delete_all
      redirect_to broken_versions_path
    end

    private

    def handle_delete(id, database)
      ActualDbSchema::Migration.instance.delete(id, database)
      flash[:notice] = "Migration #{id} was successfully deleted."
    rescue StandardError => e
      flash[:alert] = e.message
    end

    def handle_delete_all
      ActualDbSchema::Migration.instance.delete_all
      flash[:notice] = "All broken versions were successfully deleted."
    rescue StandardError => e
      flash[:alert] = e.message
    end

    helper_method def broken_versions
      @broken_versions ||= ActualDbSchema::Migration.instance.broken_versions
    end
  end
end
