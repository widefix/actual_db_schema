# frozen_string_literal: true

module ActualDbSchema
  # Controller to display the list of migrations for each database connection.
  class MigrationsController < ActionController::Base
    def index; end

    private

    helper_method def migrations
      @migrations ||= ActualDbSchema::Migration.all
    end
  end
end
