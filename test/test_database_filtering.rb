# frozen_string_literal: true

require "test_helper"

describe "database filtering" do
  let(:utils) do
    TestUtils.new(
      migrations_path: ["db/migrate", "db/migrate_secondary"],
      migrated_path: ["tmp/migrated", "tmp/migrated_migrate_secondary"]
    )
  end

  before do
    # Reset to default config
    ActualDbSchema.config.excluded_databases = []
  end

  describe "with excluded_databases configuration" do
    it "excludes databases from the excluded_databases list" do
      db_config = TestingState.db_config.dup
      utils.reset_database_yml(db_config)
      ActiveRecord::Base.configurations = { "test" => db_config }
      ActiveRecord::Tasks::DatabaseTasks.database_configuration = { "test" => db_config }
      
      # Configure to exclude secondary database
      ActualDbSchema.config.excluded_databases = [:secondary]
      
      # Get the migration context instance
      context = ActualDbSchema::MigrationContext.instance
      
      # Verify only primary database is included
      configs = context.send(:configs)
      config_names = configs.map { |c| c.respond_to?(:name) ? c.name.to_sym : :primary }
      
      assert_includes config_names, :primary
      refute_includes config_names, :secondary
    end

    it "allows excluding multiple databases" do
      db_config = {
        "primary" => TestingState.db_config["primary"],
        "secondary" => TestingState.db_config["secondary"],
        "queue" => {
          "adapter" => "sqlite3",
          "database" => "tmp/queue.sqlite3",
          "migrations_paths" => Rails.root.join("db", "migrate_queue").to_s
        }
      }
      
      utils.reset_database_yml(db_config)
      ActiveRecord::Base.configurations = { "test" => db_config }
      ActiveRecord::Tasks::DatabaseTasks.database_configuration = { "test" => db_config }
      
      # Configure to exclude secondary and queue databases
      ActualDbSchema.config.excluded_databases = [:secondary, :queue]
      
      # Get the migration context instance
      context = ActualDbSchema::MigrationContext.instance
      
      # Verify only primary database is included
      configs = context.send(:configs)
      config_names = configs.map { |c| c.respond_to?(:name) ? c.name.to_sym : :primary }
      
      assert_includes config_names, :primary
      refute_includes config_names, :secondary
      refute_includes config_names, :queue
    end

    it "processes all databases when excluded_databases is empty" do
      db_config = TestingState.db_config.dup
      utils.reset_database_yml(db_config)
      ActiveRecord::Base.configurations = { "test" => db_config }
      ActiveRecord::Tasks::DatabaseTasks.database_configuration = { "test" => db_config }
      
      ActualDbSchema.config.excluded_databases = []
      
      context = ActualDbSchema::MigrationContext.instance
      configs = context.send(:configs)
      config_names = configs.map { |c| c.respond_to?(:name) ? c.name.to_sym : :primary }
      
      assert_includes config_names, :primary
      assert_includes config_names, :secondary
    end
  end

  describe "environment variable ACTUAL_DB_SCHEMA_EXCLUDED_DATABASES" do
    it "parses comma-separated database names from environment variable" do
      ENV["ACTUAL_DB_SCHEMA_EXCLUDED_DATABASES"] = "queue,cable"
      
      # Create a new configuration to pick up the env var
      config = ActualDbSchema::Configuration.new
      
      assert_equal [:queue, :cable], config.excluded_databases
    ensure
      ENV.delete("ACTUAL_DB_SCHEMA_EXCLUDED_DATABASES")
    end

    it "handles whitespace in environment variable" do
      ENV["ACTUAL_DB_SCHEMA_EXCLUDED_DATABASES"] = "queue, cable, cache"
      
      config = ActualDbSchema::Configuration.new
      
      assert_equal [:queue, :cable, :cache], config.excluded_databases
    ensure
      ENV.delete("ACTUAL_DB_SCHEMA_EXCLUDED_DATABASES")
    end

    it "returns empty array when environment variable is not set" do
      ENV.delete("ACTUAL_DB_SCHEMA_EXCLUDED_DATABASES")
      
      config = ActualDbSchema::Configuration.new
      
      assert_equal [], config.excluded_databases
    end

    it "handles empty string in environment variable" do
      ENV["ACTUAL_DB_SCHEMA_EXCLUDED_DATABASES"] = ""
      
      config = ActualDbSchema::Configuration.new
      
      assert_equal [], config.excluded_databases
    ensure
      ENV.delete("ACTUAL_DB_SCHEMA_EXCLUDED_DATABASES")
    end

    it "filters out empty values from comma-separated list" do
      ENV["ACTUAL_DB_SCHEMA_EXCLUDED_DATABASES"] = "queue,,cable,  ,cache"
      
      config = ActualDbSchema::Configuration.new
      
      assert_equal [:queue, :cable, :cache], config.excluded_databases
    ensure
      ENV.delete("ACTUAL_DB_SCHEMA_EXCLUDED_DATABASES")
    end
  end
end
