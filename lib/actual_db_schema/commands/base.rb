# frozen_string_literal: true

module ActualDbSchema
  module Commands
    # Base class for all commands
    class Base
      def call
        unless ActualDbSchema.config.fetch(:enabled, true)
          raise "ActualDbSchema is disabled. Set ActualDbSchema.config[:enabled] = true to enable it."
        end

        # if ActiveRecord::Migration.current_version >= 6
        #   ActiveRecord::Tasks::DatabaseTasks.raise_for_multi_db(command: "db:rollback_branches")
        # end

        call_impl
      end

      private

      def call_impl
        raise NotImplementedError
      end

      def context
        @context ||=
          ActiveRecord::Base.connection.migration_context.tap do |c|
            c.extend(ActualDbSchema::Patches::MigrationContext)
          end
      end
    end
  end
end
