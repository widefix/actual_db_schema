# frozen_string_literal: true

class TestUtils
  attr_accessor :migrations_path, :migrated_path

  def initialize(migrations_path: "db/migrate", migrated_path: "tmp/migrated")
    @migrations_path = migrations_path
    @migrated_path = migrated_path
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

  def run_sql(sql)
    ActiveRecord::Base.connection.execute(sql)
  end

  def applied_migrations
    run_sql("select * from schema_migrations").map do |row|
      row["version"]
    end
  end

  def clear_schema
    run_sql("delete from schema_migrations")
  end

  def delete_migrations_files
    Dir.glob(app_file("#{migrations_path}/**/*.rb")).each do |file|
      remove_app_dir(file)
    end
  end

  def define_migration_file(filename, content)
    File.write(app_file("#{migrations_path}/#{filename}"), content, mode: "w")
  end

  def define_migrations
    {
      first: "20130906111511_first.rb",
      second: "20130906111512_second.rb"
    }.each do |key, file_name|
      define_migration_file(file_name, <<~RUBY)
        class #{key.to_s.camelize} < ActiveRecord::Migration[6.0]
          def up
            TestingState.up << :#{key}
          end

          def down
            TestingState.down << :#{key}
          end
        end
      RUBY
    end
  end

  def prepare_phantom_migrations
    run_migrations
    delete_migrations_files # simulate switching branches
  end

  def cleanup
    delete_migrations_files
    if ActiveRecord::SchemaMigration.respond_to?(:create_table)
      ActiveRecord::SchemaMigration.create_table
    else
      ActiveRecord::SchemaMigration.new(ActiveRecord::Base.connection).create_table
    end
    run_sql("delete from schema_migrations")
    remove_app_dir(migrated_path)
    define_migrations
    Rails.application.load_tasks
    TestingState.reset
  end

  def migrated_files
    Dir.glob(app_file("#{migrated_path}/*.rb")).map { |f| File.basename(f) }.sort
  end
end
