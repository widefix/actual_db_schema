# frozen_string_literal: true

module ActualDbSchema
  # It isolates the namespace to avoid conflicts with the main application.
  class Engine < ::Rails::Engine
    isolate_namespace ActualDbSchema

    initializer "actual_db_schema.initialize" do |app|
      if ActualDbSchema.config[:ui_enabled]
        app.routes.append do
          mount ActualDbSchema::Engine => "/rails"
        end
      end
    end

    initializer "actual_db_schema.schema_dump_exclusions" do
      ActiveSupport.on_load(:active_record) do
        ActualDbSchema::Engine.apply_schema_dump_exclusions
      end
    end

    def self.apply_schema_dump_exclusions
      ignore_schema_dump_table(ActualDbSchema::Store::DbAdapter::TABLE_NAME)
      ignore_schema_dump_table(ActualDbSchema::RollbackStatsRepository::TABLE_NAME)
      return unless schema_dump_flags_supported?
      return unless schema_dump_connection_available?

      apply_structure_dump_flags(ActualDbSchema::Store::DbAdapter::TABLE_NAME)
      apply_structure_dump_flags(ActualDbSchema::RollbackStatsRepository::TABLE_NAME)
    end

    class << self
      private

      def ignore_schema_dump_table(table_name)
        return unless defined?(ActiveRecord::SchemaDumper)
        return unless ActiveRecord::SchemaDumper.respond_to?(:ignore_tables)

        ActiveRecord::SchemaDumper.ignore_tables |= [table_name]
      end

      def schema_dump_flags_supported?
        defined?(ActiveRecord::Tasks::DatabaseTasks) &&
          ActiveRecord::Tasks::DatabaseTasks.respond_to?(:structure_dump_flags)
      end

      # Avoid touching db config unless we explicitly use DB storage
      # or a connection is already available.
      def schema_dump_connection_available?
        has_connection = begin
          ActiveRecord::Base.connection_pool.connected?
        rescue ActiveRecord::ConnectionNotDefined, ActiveRecord::ConnectionNotEstablished
          false
        end

        ActualDbSchema.config[:migrations_storage] == :db || has_connection
      end

      def apply_structure_dump_flags(table_name)
        flags = Array(ActiveRecord::Tasks::DatabaseTasks.structure_dump_flags)
        adapter = ActualDbSchema.db_config[:adapter].to_s
        database = database_name

        if adapter.match?(/postgres/i)
          flag = "--exclude-table=#{table_name}*"
          flags << flag unless flags.include?(flag)
        elsif adapter.match?(/mysql/i) && database
          flag = "--ignore-table=#{database}.#{table_name}"
          flags << flag unless flags.include?(flag)
        end

        ActiveRecord::Tasks::DatabaseTasks.structure_dump_flags = flags
      end

      def database_name
        database = ActualDbSchema.db_config[:database]
        if database.nil? && ActiveRecord::Base.respond_to?(:connection_db_config)
          database = ActiveRecord::Base.connection_db_config&.database
        end
        database
      end
    end
  end
end
