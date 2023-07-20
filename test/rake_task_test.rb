# frozen_string_literal: true

require "test_helper"

class TestingState
  class << self
    attr_accessor :up, :down
  end

  def self.reset
    self.up = []
    self.down = []
  end

  reset
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

def dump_schema
  Rake::Task["db:schema:dump"].invoke
  Rake::Task["db:schema:dump"].reenable
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
  Dir.glob(app_file("db/migrate/*.rb")).each do |file|
    remove_app_dir(file)
  end
end

def define_migration_file(filename, content)
  File.write(app_file("db/migrate/#{filename}"), content, mode: "w")
end

def define_migrations
  {
    first: "20130906111511_first.rb",
    second: "20130906111512_second.rb"
  }.each do |key, file_name|
    define_migration_file(file_name, <<~RUBY)
      class #{key.to_s.camelize} < ActiveRecord::Migration[7.0]
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

describe "db:rollback_branches" do
  let(:migrated_files) do
    Dir.glob(app_file("tmp/migrated/*.rb")).map { |f| File.basename(f) }.sort
  end

  before do
    delete_migrations_files
    ActiveRecord::SchemaMigration.create_table
    run_sql("delete from schema_migrations")
    remove_app_dir("tmp/migrated")
    define_migrations
    Rails.application.load_tasks
    TestingState.reset
  end

  it "creates the tmp/migrated folder" do
    refute File.exist?(app_file("tmp/migrated"))
    run_migrations
    assert File.exist?(app_file("tmp/migrated"))
  end

  it "migrates the migrations" do
    assert_empty applied_migrations
    run_migrations
    assert_equal %w[20130906111511 20130906111512], applied_migrations
  end

  it "keeps migrated migrations in tmp/migrated folder" do
    run_migrations
    assert_equal %w[20130906111511_first.rb 20130906111512_second.rb], migrated_files
  end

  it "rolls back the migrations in the reversed order" do
    prepare_phantom_migrations
    assert_empty TestingState.down
    run_migrations
    assert_equal %i[second first], TestingState.down
  end

  describe "with irreversible migration" do
    before do
      define_migration_file("20130906111513_irreversible.rb", <<~RUBY)
        class Irreversible < ActiveRecord::Migration[7.0]
          def up
            TestingState.up << :irreversible
          end

          def down
            raise ActiveRecord::IrreversibleMigration
          end
        end
      RUBY
    end

    it "keeps track of the irreversible migrations" do
      prepare_phantom_migrations
      assert_equal %i[first second irreversible], TestingState.up
      assert_empty ActualDbSchema.failed
      run_migrations
      assert_equal(%w[20130906111513_irreversible.rb], ActualDbSchema.failed.map { |m| File.basename(m.filename) })
    end
  end
end
