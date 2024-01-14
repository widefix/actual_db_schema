# frozen_string_literal: true

module ActualDbSchema
  module Commands
    # Shows the list of phantom migrations
    class List < Base
      private

      def call_impl
        preambule
        table
      end

      def indexed_phantom_migrations
        @indexed_phantom_migrations ||= context.migrations.index_by { |m| m.version.to_s }
      end

      def preambule
        puts "\nPhantom migrations\n\n"
        puts "Below is a list of irrelevant migrations executed in unmerged branches."
        puts "To bring your database schema up to date, the migrations marked as \"up\" should be rolled back."
        puts "\ndatabase: #{ActiveRecord::Base.connection_db_config.database}\n\n"
        puts header.join("  ")
        puts "-" * separator_width
      end

      def separator_width
        (8 + 14 + branch_column_width + 2 + "Migration File".length)
      end

      def header
        [
          "Status".center(8),
          "Migration ID".ljust(14),
          "Branch".ljust(branch_column_width),
          "Migration File"
        ]
      end

      def table
        context.migrations_status.each do |status, version|
          line = line_for(status, version)
          puts line if line
        end
      end

      def line_for(status, version)
        migration = indexed_phantom_migrations[version]
        return unless migration

        [
          status.center(8),
          version.to_s.ljust(14),
          branch_for(version).ljust(14),
          migration.filename.gsub("#{Rails.root}/", "")
        ].join("  ")
      end

      def branch_for(version)
        metadata.fetch(version, {})[:branch] || "unknown"
      end

      def metadata
        @metadata ||= ActualDbSchema::Store.instance.read
      end

      def longest_branch_name
        @longest_branch_name ||=
          metadata.values.map { |v| v[:branch] }.compact.max_by(&:length) || "unknown"
      end

      def branch_column_width
        longest_branch_name.length + 2
      end
    end
  end
end
