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
        puts %(#{"Status".center(8)}  #{"Migration ID".ljust(14)}  Migration File)
        puts "-" * 50
      end

      def table
        context.migrations_status.each do |status, version|
          migration = indexed_phantom_migrations[version]
          next unless migration

          puts %(#{status.center(8)}  #{version.to_s.ljust(14)}  #{migration.filename.gsub("#{Rails.root}/", "")})
        end
      end
    end
  end
end
