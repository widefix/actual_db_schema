# frozen_string_literal: true

module ActualDbSchema
  # Handles multi-tenancy support by switching schemas for supported databases
  module MultiTenant
    include ActualDbSchema::OutputFormatter

    class << self
      def with_schema(schema_name)
        context = switch_schema(schema_name)
        yield
      ensure
        restore_context(context)
      end

      private

      def adapter_name
        ActiveRecord::Base.connection.adapter_name
      end

      def switch_schema(schema_name)
        case adapter_name
        when /postgresql/i
          switch_postgresql_schema(schema_name)
        when /mysql/i
          switch_mysql_schema(schema_name)
        else
          message = "[ActualDbSchema] Multi-tenancy not supported for adapter: #{adapter_name}. " \
            "Proceeding without schema switching."
          puts colorize(message, :gray)
        end
      end

      def switch_postgresql_schema(schema_name)
        old_search_path = ActiveRecord::Base.connection.schema_search_path
        ActiveRecord::Base.connection.schema_search_path = schema_name
        { type: :postgresql, old_context: old_search_path }
      end

      def switch_mysql_schema(schema_name)
        old_db = ActiveRecord::Base.connection.current_database
        ActiveRecord::Base.connection.execute("USE #{ActiveRecord::Base.connection.quote_table_name(schema_name)}")
        { type: :mysql, old_context: old_db }
      end

      def restore_context(context)
        return unless context

        case context[:type]
        when :postgresql
          ActiveRecord::Base.connection.schema_search_path = context[:old_context] if context[:old_context]
        when :mysql
          return unless context[:old_context]

          ActiveRecord::Base.connection.execute(
            "USE #{ActiveRecord::Base.connection.quote_table_name(context[:old_context])}"
          )
        end
      end
    end
  end
end
