# frozen_string_literal: true

module ActualDbSchema
  # Controller to display the list of phantom migrations for each database connection.
  class MigrationsController < ActionController::Base
    def index; end

    def show
      render :not_found, status: 404 unless migration
    end

    def rollback
      rollback_migration(params[:id], params[:database])
      redirect_to migrations_path
    end

    private

    helper_method def migrations
      ActualDbSchema::Migration.instance.all
    end

    helper_method def migration
      ActualDbSchema::Migration.find(params[:id], params[:database])
    end

    def rollback_migration(version, database)
      ActualDbSchema.for_each_db_connection do
        next unless ActualDbSchema.db_config[:database] == database

        context = ActualDbSchema.prepare_context
        if context.migrations.detect { |m| m.version.to_s == version }
          context.run(:down, version.to_i)
          break
        end
      end
    end

    def build_migration_struct(status, migration)
      MigrationStruct.new(
        status: status,
        version: migration.version.to_s,
        name: migration.name,
        branch: ActualDbSchema.branch_for(ActualDbSchema.metadata, migration.version),
        database: ActualDbSchema.db_config[:database],
        filename: migration.filename
      )
    end
  end
end
