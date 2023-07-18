# frozen_string_literal: true

require "test_helper"

def app_file(path)
  Rails.application.config.root.join(path)
end

def remove_app_dir(name)
  FileUtils.rm_rf(Rails.application.config.root.join(name))
end

def run_migrations
  Rake::Task["db:migrate"].invoke
end

describe "db:rollback_branches" do
  before do
    remove_app_dir("tmp/migrated")
    Rails.application.load_tasks
  end

  it "creates the tmp/migrated folder" do
    refute File.exist?(app_file("tmp/migrated"))
    run_migrations
    assert File.exist?(app_file("tmp/migrated"))
  end

  it "keeps migrated migrations in tmp/migrated folder" do
    run_migrations
    debugger
    # raise Dir[app_file("tmp/migrated")].inspect
  end
end
