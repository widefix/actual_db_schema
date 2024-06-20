# frozen_string_literal: true

module ActualDbSchema
  module Commands
    # Rolls back all phantom migrations
    class Rollback < Base
      def initialize(manual_mode: false)
        @manual_mode = manual_mode
        super()
      end

      private

      def call_impl
        context.rollback_branches(manual_mode: @manual_mode)

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
