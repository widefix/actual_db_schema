module ActualDbSchema
  module Commands
    class List
      def call
        unless ActualDbSchema.config.fetch(:enabled, true)
          raise "ActualDbSchema is disabled. Set ActualDbSchema.config[:enabled] = true to enable it."
        end

        context = ActiveRecord::Base.connection.migration_context
        context.extend(ActualDbSchema::Patches::MigrationContext)

        puts "\nPhantom migrations\n\n"
        puts "Below is a list of irrelevant migrations executed in unmerged branches."
        puts "To bring your database schema up to date, the migrations marked as \"up\" should be rolled back."
        puts "\ndatabase: #{ActiveRecord::Base.connection_db_config.database}\n\n"
        puts %(#{"Status".center(8)}  #{"Migration ID".ljust(14)}  Migration File)
        puts "-" * 50

        phantom_migrations = context.migrations.index_by { |m| m.version.to_s }

        context.migrations_status.each do |status, version|
          migration = phantom_migrations[version]
          next unless migration

          puts %(#{status.center(8)}  #{version.to_s.ljust(14)}  #{migration.filename.gsub("#{Rails.root}/", "")})
        end
      end
    end
  end
end
