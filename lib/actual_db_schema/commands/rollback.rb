# frozen_string_literal: true

module ActualDbSchema
  module Commands
    # Rolls back all phantom migrations
    class Rollback < Base
      UNICODE_COLORS = {
        red: 31,
        green: 32,
        yellow: 33
      }.freeze

      def initialize(context, manual_mode: false)
        @manual_mode = manual_mode || manual_mode_default?
        super(context)
      end

      private

      def call_impl
        context.rollback_branches(manual_mode: @manual_mode)

        return if ActualDbSchema.failed.empty?

        puts_preamble
        puts_into
        puts ""
        puts failed_migrations_list
        puts_preamble
      end

      def failed_migrations_list
        ActualDbSchema.failed.map.with_index(1) do |failed, index|
          filename = failed.short_filename
          exception = failed.exception
          <<~MSG
            \t#{colorize("[Migration##{index}]", :yellow)}
            \t- #{filename}

            \t\t#{exception.inspect.gsub("\n", "\n\t  ")}
          MSG
        end
      end

      def puts_preamble
        puts ""
        puts %(\u2757\u2757\u2757 #{colorize("[ActualDbSchema]", :red)})
        puts ""
      end

      def puts_into
        msg = "#{ActualDbSchema.failed.count} phantom migration(s) could not be rolled back automatically."
        msg += " Roll them back or fix manually:"
        puts colorize(msg, :red)
      end

      def manual_mode_default?
        ActualDbSchema.config[:auto_rollback_disabled]
      end

      def colorize(text, color)
        code = UNICODE_COLORS.fetch(color, 37)
        "\e[#{code}m#{text}\e[0m"
      end
    end
  end
end
