# frozen_string_literal: true

module ActualDbSchema
  module Commands
    # Rolls back all phantom migrations
    class Rollback < Base
      include ActualDbSchema::OutputFormatter
      include ActionView::Helpers::TextHelper

      def initialize(context, manual_mode: false)
        @manual_mode = manual_mode || manual_mode_default?
        super(context)
      end

      private

      def call_impl
        rolled_back = context.rollback_branches(manual_mode: @manual_mode)

        return unless rolled_back

        ActualDbSchema.failed.empty? ? print_success : print_error
      end

      def print_success
        puts colorize("[ActualDbSchema] All phantom migrations rolled back successfully! 🎉", :green)
      end

      def print_error
        header_message = <<~HEADER
          #{ActualDbSchema.failed.count} phantom migration(s) could not be rolled back automatically.

          Try these steps to fix and move forward:
            1. Ensure the migrations are reversible (define #up and #down methods or use #reversible).
            2. If the migration references code or tables from another branch, restore or remove them.
            3. Once fixed, run `rails db:migrate` again.

          Below are the details of the problematic migrations:
        HEADER

        print_error_summary("#{header_message}\n#{failed_migrations_list}")
      end

      def failed_migrations_list
        ActualDbSchema.failed.map.with_index(1) do |failed, index|
          <<~MIGRATION
            #{colorize("Migration ##{index}:", :yellow)}
              File: #{failed.short_filename}
              Branch: #{failed.branch}
          MIGRATION
        end.join("\n")
      end

      def print_error_summary(content)
        width = 100
        indent = 4
        gem_name = "ActualDbSchema"

        puts colorize("╔═ [#{gem_name}] #{"═" * (width - gem_name.length - 5)}╗", :red)
        print_wrapped_content(content, width, indent)
        puts colorize("╚#{"═" * width}╝", :red)
      end

      def print_wrapped_content(content, width, indent)
        usable_width = width - indent - 4
        wrapped_content = word_wrap(content, line_width: usable_width)
        wrapped_content.each_line do |line|
          puts "#{" " * indent}#{line.chomp}"
        end
      end

      def manual_mode_default?
        ActualDbSchema.config[:auto_rollback_disabled]
      end
    end
  end
end
