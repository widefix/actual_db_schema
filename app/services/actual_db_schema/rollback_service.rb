# frozen_string_literal: true

module ActualDbSchema
  # Service class to handle the rollback of database migrations.
  class RollbackService
    def self.perform(version, database)
      ActualDbSchema.for_each_db_connection do
        next unless ActualDbSchema.db_config[:database] == database

        context = ActualDbSchema.prepare_context
        if context.migrations.detect { |m| m.version.to_s == version }
          context.run(:down, version.to_i)
          break
        end
      end
    end
  end
end
