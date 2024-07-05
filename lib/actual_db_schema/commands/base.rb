# frozen_string_literal: true

module ActualDbSchema
  module Commands
    # Base class for all commands
    class Base
      def initialize(context: nil)
        @context = context
      end

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

      attr_reader :context
    end
  end
end
