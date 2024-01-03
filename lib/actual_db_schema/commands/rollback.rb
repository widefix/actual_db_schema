module ActualDbSchema
  module Commands
    class Rollback
      def call
        unless ActualDbSchema.config.fetch(:enabled, true)
          raise "ActualDbSchema is disabled. Set ActualDbSchema.config[:enabled] = true to enable it."
        end

        if ActiveRecord::Migration.current_version >= 6
          ActiveRecord::Tasks::DatabaseTasks.raise_for_multi_db(command: "db:rollback_branches")
        end

        context = ActiveRecord::Base.connection.migration_context
        context.extend(ActualDbSchema::Patches::MigrationContext)
        context.rollback_branches
        if ActualDbSchema.failed.any?
          puts ""
          puts "[ActualDbSchema] Irreversible migrations were found from other branches. Roll them back or fix manually:"
          puts ""
          puts ActualDbSchema.failed.map { |migration| "- #{migration.filename}" }.join("\n")
          puts ""
        end
      end
    end
  end
end
