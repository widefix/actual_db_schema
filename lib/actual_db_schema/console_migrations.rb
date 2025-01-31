# frozen_string_literal: true

module ActualDbSchema
  # Provides methods for executing schema modification commands directly in the Rails console.
  module ConsoleMigrations
    extend self

    SCHEMA_METHODS = %i[
      create_table
      create_join_table
      drop_table
      change_table
      add_column
      remove_column
      change_column
      change_column_null
      change_column_default
      rename_column
      add_index
      remove_index
      rename_index
      add_timestamps
      remove_timestamps
      reversible
      add_reference
      remove_reference
      add_foreign_key
      remove_foreign_key
    ].freeze

    SCHEMA_METHODS.each do |method_name|
      define_method(method_name) do |*args, **kwargs, &block|
        if kwargs.any?
          migration_instance.public_send(method_name, *args, **kwargs, &block)
        else
          migration_instance.public_send(method_name, *args, &block)
        end
      end
    end

    private

    def migration_instance
      @migration_instance ||= Class.new(ActiveRecord::Migration[ActiveRecord::Migration.current_version]) {}.new
    end
  end
end
