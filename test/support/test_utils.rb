# frozen_string_literal: true

class TestUtils
  attr_accessor :migrations_paths, :migrated_paths, :migration_timestamps, :connection_prefix

  MIGRATED_PATHS = {
    primary: "tmp/migrated",
    secondary: "tmp/migrated_migrate_secondary"
  }.freeze

  MIGRATION_PATHS = {
    primary: "db/migrate",
    secondary: "db/migrate_secondary"
  }.freeze

  def initialize(migrations_path: "db/migrate", migrated_path: "tmp/migrated")
    @migrations_paths = Array.wrap(migrations_path)
    @migrated_paths = Array.wrap(migrated_path)
    @migration_timestamps = %w[
      20130906111511
      20130906111512
      20130906111514
      20130906111515
    ]
  end

  def app_file(path)
    Rails.application.config.root.join(path)
  end

  def remove_app_dir(name)
    FileUtils.rm_rf(app_file(name))
  end

  def run_migrations
    schemas = ActualDbSchema.config[:multi_tenant_schemas]&.call
    if schemas
      schemas.each { |schema| ActualDbSchema::MultiTenant.with_schema(schema) { run_migration_tasks } }
    else
      run_migration_tasks
    end
  end

  def applied_migrations(db_config = nil)
    if db_config
      db_config.each_with_object([]) do |(_, config), acc|
        ActiveRecord::Base.establish_connection(**config)
        acc.concat(applied_migrations_call)
      end
    else
      applied_migrations_call
    end
  end

  def simulate_input(input)
    $stdin = StringIO.new("#{([input] * 999).join("\n")}\n")
    yield
  end

  def delete_migrations_files(prefix_name = nil)
    path = MIGRATION_PATHS.fetch(prefix_name&.to_sym, migrations_paths.first)
    delete_migrations_files_for(path)
  end

  def delete_migrations_files_for(path)
    Dir.glob(app_file("#{path}/**/*.rb")).each do |file|
      remove_app_dir(file)
    end
  end

  def define_migration_file(filename, content, prefix: nil)
    path =
      case prefix
      when "primary"
        "db/migrate"
      when "secondary"
        "db/migrate_secondary"
      when nil
        migrations_paths.first
      else
        raise "Unknown prefix: #{prefix}"
      end
    File.write(app_file("#{path}/#{filename}"), content, mode: "w")
  end

  def define_migrations(prefix_name = nil)
    prefix = "_#{prefix_name}" if prefix_name
    raise "No migration timestamps left" if @migration_timestamps.size < 2

    {
      first: "#{@migration_timestamps.shift}_first#{prefix}.rb",
      second: "#{@migration_timestamps.shift}_second#{prefix}.rb"
    }.each do |key, file_name|
      define_migration_file(file_name, <<~RUBY, prefix: prefix_name)
        class #{key.to_s.camelize}#{prefix_name.to_s.camelize} < ActiveRecord::Migration[6.0]
          def up
            TestingState.up << :#{key}#{prefix}
          end

          def down
            TestingState.down << :#{key}#{prefix}
          end
        end
      RUBY
    end
  end

  def reset_database_yml(db_config)
    database_yml_path = Rails.root.join("config", "database.yml")
    File.delete(database_yml_path) if File.exist?(database_yml_path)

    # Ensure we have a clean database state
    if db_config.is_a?(Hash) && db_config.key?("primary")
      # Multi-database configuration
      db_config.each do |name, config|
        database_path = Rails.root.join(config["database"])
        File.delete(database_path) if File.exist?(database_path)
      end

      File.open(database_yml_path, "w") do |file|
        file.write({
          "test" => db_config
        }.to_yaml)
      end
    else
      # Single database configuration
      database_path = Rails.root.join(db_config["database"])
      File.delete(database_path) if File.exist?(database_path)

      File.open(database_yml_path, "w") do |file|
        file.write({
          "test" => db_config
        }.to_yaml)
      end
    end
  end

  def prepare_phantom_migrations(db_config = nil)
    run_migrations
    if db_config
      db_config.each_key do |name|
        delete_migrations_files(name) # simulate switching branches
      end
    else
      delete_migrations_files
    end
  end

  def cleanup(db_config = nil)
    if db_config
      db_config.each do |name, c|
        ActiveRecord::Base.establish_connection(**c)
        cleanup_call(name)
      end
    else
      cleanup_call
    end
    TestingState.reset
  end

  def migrated_files(db_config = nil)
    if db_config
      db_config.each_with_object([]) do |(prefix_name, config), acc|
        ActiveRecord::Base.establish_connection(**config)
        acc.concat(migrated_files_call(prefix_name))
      end
    else
      migrated_files_call
    end
  end

  def branch_for(version)
    metadata.fetch(version.to_s, {})[:branch]
  end

  def define_acronym(acronym)
    ActiveSupport::Inflector.inflections(:en) do |inflect|
      inflect.acronym acronym
    end
  end

  def primary_database
    TestingState.db_config["primary"]["database"]
  end

  def secondary_database
    TestingState.db_config["secondary"]["database"]
  end

  private

  def run_migration_tasks
    if ActualDbSchema.config[:multi_tenant_schemas].present?
      ActiveRecord::MigrationContext.new(Rails.root.join("db/migrate"), schema_migration_class).migrate
    end

    Rake::Task["db:migrate"].invoke
    Rake::Task["db:migrate"].reenable
    Rake::Task["db:rollback_branches"].reenable
  end

  def cleanup_call(prefix_name = nil)
    delete_migrations_files(prefix_name)
    create_schema_migration_table
    clear_schema_call
    remove_app_dir(MIGRATED_PATHS.fetch(prefix_name&.to_sym, migrated_paths.first))
    define_migrations(prefix_name)
    Rake::Task.clear
    Rails.application.load_tasks
  end

  def create_schema_migration_table
    schema_migration_class.create_table
  end

  def schema_migration_class
    if ActiveRecord::SchemaMigration.respond_to?(:create_table)
      ActiveRecord::SchemaMigration
    else
      ar_version = Gem::Version.new(ActiveRecord::VERSION::STRING)
      if ar_version >= Gem::Version.new("7.2.0") || (ar_version >= Gem::Version.new("7.1.0") && ar_version.prerelease?)
        ActiveRecord::SchemaMigration.new(ActiveRecord::Base.connection_pool)
      else
        ActiveRecord::SchemaMigration.new(ActiveRecord::Base.connection)
      end
    end
  end

  def migrated_files_call(prefix_name = nil)
    migrated_path = ActualDbSchema.config[:migrated_folder].presence || migrated_paths.first
    path = MIGRATED_PATHS.fetch(prefix_name&.to_sym, migrated_path.to_s)
    Dir.glob(app_file("#{path}/*.rb")).map { |f| File.basename(f) }.sort
  end

  def clear_schema_call
    run_sql("delete from schema_migrations")
  end

  def applied_migrations_call
    run_sql("select * from schema_migrations").map do |row|
      row.is_a?(Hash) ? row["version"] : row[0]
    end
  end

  def run_sql(sql)
    ActiveRecord::Base.connection.execute(sql)
  end

  def metadata
    ActualDbSchema::Store.instance.read
  end
end
