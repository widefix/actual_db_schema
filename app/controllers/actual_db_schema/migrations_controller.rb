# frozen_string_literal: true

module ActualDbSchema
  # Controller to display the list of phantom migrations for each database connection.
  class MigrationsController < ActionController::Base
    def index; end

    def show; end

    def rollback
      rollback_migration(params[:id], params[:database])
      redirect_to migrations_path
    end

    private

    helper_method def migrations
      ActualDbSchema::Migration.instance.all
    end

    helper_method def load_migration(version, database)
      ActualDbSchema.for_each_db_connection do
        next unless ActualDbSchema.db_config[:database] == database

        context = ActualDbSchema.prepare_context
        migration = find_migration_in_context(context, version)
        return migration if migration
      end
      nil
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

    def find_migration_in_context(context, version)
      migration = context.migrations.detect { |m| m.version.to_s == version }
      return unless migration

      status = context.migrations_status.detect { |_s, v| v.to_s == version }&.first || "unknown"
      build_migration_struct(status, migration)
    end
  end
end
