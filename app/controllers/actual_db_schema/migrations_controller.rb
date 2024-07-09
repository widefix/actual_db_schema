# frozen_string_literal: true

module ActualDbSchema
  # Controller to display the list of migrations for each database connection.
  class MigrationsController < ActionController::Base
    def index; end

    private

    helper_method def migrations
      @migrations ||= all_migrations
    end

    def all_migrations
      all_migrations = []

      MigrationContext.instance.each do |context|
        applied_migrations = context.get_all_versions

        applied_migrations.each do |version|
          migration_info = { version: version }
          all_migrations << migration_info
        end
      end

      all_migrations
    end
  end
end
