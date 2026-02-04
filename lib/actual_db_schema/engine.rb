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
        table_name = ActualDbSchema::Store::DbAdapter::TABLE_NAME

        if defined?(ActiveRecord::SchemaDumper) && ActiveRecord::SchemaDumper.respond_to?(:ignore_tables)
          ActiveRecord::SchemaDumper.ignore_tables |= [table_name]
        end

        next unless defined?(ActiveRecord::Tasks::DatabaseTasks)
        next unless ActiveRecord::Tasks::DatabaseTasks.respond_to?(:structure_dump_flags)

        # Avoid touching db config unless we explicitly use DB storage
        # or a connection is already available.
        has_connection = begin
          ActiveRecord::Base.connection_pool.connected?
        rescue ActiveRecord::ConnectionNotDefined, ActiveRecord::ConnectionNotEstablished
          false
        end
        next unless ActualDbSchema.config[:migrations_storage] == :db || has_connection

        flags = Array(ActiveRecord::Tasks::DatabaseTasks.structure_dump_flags)
        adapter = ActualDbSchema.db_config[:adapter].to_s
        database = ActualDbSchema.db_config[:database]
        if database.nil? && ActiveRecord::Base.respond_to?(:connection_db_config)
          database = ActiveRecord::Base.connection_db_config&.database
        end

        if adapter.match?(/postgres/i)
          flag = "--exclude-table=#{table_name}*"
          flags << flag unless flags.include?(flag)
        elsif adapter.match?(/mysql/i) && database
          flag = "--ignore-table=#{database}.#{table_name}"
          flags << flag unless flags.include?(flag)
        end

        ActiveRecord::Tasks::DatabaseTasks.structure_dump_flags = flags
      end
    end
  end
end
