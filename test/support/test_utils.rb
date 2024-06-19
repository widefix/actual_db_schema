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
    Rake::Task["db:migrate"].invoke
    Rake::Task["db:migrate"].reenable
    Rake::Task["db:rollback_branches"].reenable
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

  def clear_schema(db_config = nil)
    if db_config
      db_config.each_value do |config|
        ActiveRecord::Base.establish_connection(**config)
        clear_schema_call
      end
    else
      clear_schema_call
    end
  end

  def simulate_input(input)
    original_stdin = $stdin
    fake_stdin = StringIO.new("#{([input] * 99).join("\n")}\n")
    $stdin = fake_stdin
    yield
  ensure
    $stdin = original_stdin
  end

  def delete_migrations_files(prefix_name = nil)
    path = MIGRATION_PATHS.fetch(prefix_name&.to_sym, migrations_paths.first)
    delete_migrations_files_for(path)
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

  private

  def cleanup_call(prefix_name = nil)
    delete_migrations_files(prefix_name)
    create_schema_migration_table
    run_sql("delete from schema_migrations")
    remove_app_dir(MIGRATED_PATHS.fetch(prefix_name&.to_sym, migrated_paths.first))
    define_migrations(prefix_name)
    Rails.application.load_tasks
  end

  def create_schema_migration_table
    if ActiveRecord::SchemaMigration.respond_to?(:create_table)
      ActiveRecord::SchemaMigration.create_table
    else
      ar_version = Gem::Version.new(ActiveRecord::VERSION::STRING)
      if ar_version >= Gem::Version.new("7.2.0") || (ar_version >= Gem::Version.new("7.1.0") && ar_version.prerelease?)
        ActiveRecord::SchemaMigration.new(ActiveRecord::Base.connection_pool).create_table
      else
        ActiveRecord::SchemaMigration.new(ActiveRecord::Base.connection).create_table
      end
    end
  end

  def delete_migrations_files_for(path)
    Dir.glob(app_file("#{path}/**/*.rb")).each do |file|
      remove_app_dir(file)
    end
  end

  def migrated_files_call(prefix_name = nil)
    path = MIGRATED_PATHS.fetch(prefix_name&.to_sym, migrated_paths.first)
    Dir.glob(app_file("#{path}/*.rb")).map { |f| File.basename(f) }.sort
  end

  def clear_schema_call
    run_sql("delete from schema_migrations")
  end

  def applied_migrations_call
    run_sql("select * from schema_migrations").map do |row|
      row["version"]
    end
  end

  def run_sql(sql)
    ActiveRecord::Base.connection.execute(sql)
  end
end
