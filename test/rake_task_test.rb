# frozen_string_literal: true

require "test_helper"

def app_file(path)
  Rails.application.config.root.join(path)
end

def remove_app_dir(name)
  FileUtils.rm_rf(app_file(name))
end

def run_migrations
  Rake::Task["db:migrate"].invoke
  Rake::Task["db:migrate"].reenable
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

describe "db:rollback_branches" do
  before do
    run_sql("delete from schema_migrations")
    remove_app_dir("tmp/migrated")
    Rails.application.load_tasks
  end

  it "creates the tmp/migrated folder" do
    refute File.exist?(app_file("tmp/migrated"))
    run_migrations
    dump_schema
    assert File.exist?(app_file("tmp/migrated"))
  end

  it "migrates the migrations" do
    assert_empty applied_migrations
    run_migrations
    assert_equal %w[20130906111511 20130906111512], applied_migrations
  end

  it "keeps migrated migrations in tmp/migrated folder" do
    run_migrations
    # raise Dir[app_file("tmp/migrated")].inspect
  end
end
