# frozen_string_literal: true

module ActualDbSchema
  module Commands
    # Base class for all commands
    class Base
      def call
        unless ActualDbSchema.config.fetch(:enabled, true)
          raise "ActualDbSchema is disabled. Set ActualDbSchema.config[:enabled] = true to enable it."
        end

        call_impl
      end

      private

      def call_impl
        raise NotImplementedError
      end

      def context
        @context ||= fetch_migration_context.tap do |c|
          c.extend(ActualDbSchema::Patches::MigrationContext)
        end
      end

      def fetch_migration_context
        ar_version = Gem::Version.new(ActiveRecord::VERSION::STRING)
        if ar_version >= Gem::Version.new("7.2.0") ||
           (ar_version >= Gem::Version.new("7.1.0") && ar_version.prerelease?)
          ActiveRecord::Base.connection_pool.migration_context
        else
          ActiveRecord::Base.connection.migration_context
        end
      end
    end
  end
end
