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
        phantom_migrations = context.rollback_branches(manual_mode: @manual_mode)
        successfully_rolled_back = filter_successful_migrations(phantom_migrations)
        return if phantom_migrations.empty?

        puts_preamble
        puts_intro_info
        puts_successful_rollback_info(successfully_rolled_back) unless successfully_rolled_back.empty?
        puts_unsuccessful_rollback_info unless ActualDbSchema.failed.empty?
        puts_preamble
      end

      def filter_successful_migrations(phantom_migrations)
        phantom_migrations.reject { |migration| ActualDbSchema.failed.map(&:migration).include?(migration) }
      end

      def puts_successful_rollback_info(list)
        msg = "#{list.count} phantom #{"migration".pluralize(list.count)} were successfully rolled back."

        puts colorize(msg, :green)
        puts ""
        puts successful_rollback_list(list)
        puts ""
      end

      def successful_rollback_list(list)
        list.map.with_index(1) do |migration, index|
          filename = migration.filename.sub(File.join(Rails.root, "/"), "")
          <<~MSG
            \t#{colorize("[Migration##{index}]", :green)}
            \t- #{filename}
          MSG
        end
      end

      def puts_unsuccessful_rollback_info
        failed_rollback_count = ActualDbSchema.failed.count
        msg = "#{failed_rollback_count} phantom #{"migration".pluralize(failed_rollback_count)} could not " \
              "be rolled back automatically. Roll them back or fix manually:"
        puts colorize(msg, :red)
        puts ""
        puts failed_migrations_list
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

      def puts_intro_info
        msg = "Phantom migrations were detected and actual_db_schema attempted to automatically roll them back.\n"
        puts colorize(msg, :yellow)
      end

      def puts_preamble
        puts ""
        puts %(\u2757\u2757\u2757 #{colorize("[ActualDbSchema]", :red)})
        puts ""
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
