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

def define_migrations
  {
    first: "20130906111511_first.rb",
    second: "20130906111512_second.rb"
  }.each do |key, file_name|
    File.write(app_file("db/migrate/#{file_name}"), %(
      class #{key.to_s.camelize} < ActiveRecord::Migration[7.0]
        def up
          TestingState.up << :#{key}
        end

        def down
          TestingState.down << :#{key}
        end
      end
    ), mode: "w")
  end
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
    run_migrations
    assert_empty TestingState.down
    delete_migrations_files # simulate switching branches
    run_migrations
    assert_equal %i[second first], TestingState.down
  end
end
