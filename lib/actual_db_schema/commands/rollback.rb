# frozen_string_literal: true

module ActualDbSchema
  module Commands
    # Rolls back all phantom migrations
    class Rollback < Base
      def initialize(manual_mode)
        debugger
        @manual_mode = manual_mode
      end

      private

      def call_impl
        debugger
        @manual_mode ? context.manually_rollback_branches : context.rollback_branches

        return if ActualDbSchema.failed.empty?

        puts ""
        puts "[ActualDbSchema] Irreversible migrations were found from other branches. Roll them back or fix manually:"
        puts ""
        puts ActualDbSchema.failed.map { |migration| "- #{migration.filename}" }.join("\n")
        puts ""
      end
    end
  end
end
