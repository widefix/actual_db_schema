# frozen_string_literal: true

module ActualDbSchema
  module Commands
    # Rolls back all phantom migrations
    class Rollback < Base
      def initialize(context, manual_mode: false)
        @manual_mode = manual_mode || manual_mode_default?
        super(context)
      end

      private

      def call_impl
        context.rollback_branches(manual_mode: @manual_mode)

        return if ActualDbSchema.failed.empty?

        puts ""
        puts "\u2757\u2757\u2757 #{colorize('[ActualDbSchema]', :red)}"
        puts ""
        puts colorize("#{ActualDbSchema.failed.count} phantom migration(s) could not be rolled back automatically. Roll them back or fix manually:", :red)
        puts ""
        puts failed_migrations_list
        puts "\u2757\u2757\u2757 #{colorize('[ActualDbSchema]', :red)}"
        puts ""
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

      def manual_mode_default?
        ActualDbSchema.config[:auto_rollback_disabled]
      end

      def colorize(text, color)
        code =
          case color
          when :red
            31
          when :green
            32
          when :yellow
            33
          else
            37
          end

        "\e[#{code}m#{text}\e[0m"
      end
    end
  end
end
