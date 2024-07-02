# frozen_string_literal: true

require_relative "../../helpers/actual_db_schema/migrations_helper"
require_relative "../../services/actual_db_schema/rollback_service"
module ActualDbSchema
  # Controller to display the list of phantom migrations for each database connection.
  class MigrationsController < ActionController::Base
    include MigrationsHelper

    def index; end

    def show; end

    def rollback
      RollbackService.perform(params[:id], params[:database])
      redirect_to migrations_path
    end
  end
end
