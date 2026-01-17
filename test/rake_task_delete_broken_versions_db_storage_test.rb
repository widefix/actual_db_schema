# frozen_string_literal: true

require "test_helper"

describe "actual_db_schema:delete_broken_versions (db storage)" do
  let(:utils) do
    TestUtils.new(
      migrations_path: ["db/migrate", "db/migrate_secondary"],
      migrated_path: ["tmp/migrated", "tmp/migrated_migrate_secondary"]
    )
  end

  before do
    ActualDbSchema.config[:migrations_storage] = :db
    utils.reset_database_yml(TestingState.db_config)
    ActiveRecord::Base.configurations = { "test" => TestingState.db_config }
    ActiveRecord::Tasks::DatabaseTasks.database_configuration = { "test" => TestingState.db_config }
    utils.cleanup(TestingState.db_config)
    utils.clear_db_storage_table(TestingState.db_config)
    utils.run_migrations
  end

  def delete_migration_files
    remove_primary_migration_files
    remove_secondary_migration_files
    delete_primary_storage_entries
    delete_secondary_storage_entries
  end

  def remove_primary_migration_files
    utils.remove_app_dir(Rails.root.join("db", "migrate", "20130906111511_first_primary.rb"))
    utils.remove_app_dir(Rails.root.join("tmp", "migrated", "20130906111511_first_primary.rb"))
  end

  def remove_secondary_migration_files
    utils.remove_app_dir(Rails.root.join("db", "migrate_secondary", "20130906111514_first_secondary.rb"))
    utils.remove_app_dir(Rails.root.join("tmp", "migrated_migrate_secondary", "20130906111514_first_secondary.rb"))
  end

  def delete_primary_storage_entries
    ActiveRecord::Base.establish_connection(TestingState.db_config["primary"])
    ActualDbSchema::Store.instance.delete(utils.app_file("tmp/migrated/20130906111511_first_primary.rb"))
  end

  def delete_secondary_storage_entries
    ActiveRecord::Base.establish_connection(TestingState.db_config["secondary"])
    secondary_path = "tmp/migrated_migrate_secondary/20130906111514_first_secondary.rb"
    ActualDbSchema::Store.instance.delete(utils.app_file(secondary_path))
  end

  describe "when versions are provided" do
    before { delete_migration_files }

    it "deletes the specified broken migrations" do
      sql = "SELECT COUNT(*) FROM schema_migrations"
      ActiveRecord::Base.establish_connection(TestingState.db_config["primary"])
      assert_equal 2, ActiveRecord::Base.connection.select_value(sql)
      ActiveRecord::Base.establish_connection(TestingState.db_config["secondary"])
      assert_equal 2, ActiveRecord::Base.connection.select_value(sql)
      Rake::Task["actual_db_schema:delete_broken_versions"].invoke("20130906111511 20130906111514")
      Rake::Task["actual_db_schema:delete_broken_versions"].reenable
      assert_match(/\[ActualDbSchema\] Migration 20130906111511 was successfully deleted./, TestingState.output)
      assert_match(/\[ActualDbSchema\] Migration 20130906111514 was successfully deleted./, TestingState.output)
      ActiveRecord::Base.establish_connection(TestingState.db_config["primary"])
      assert_equal 1, ActiveRecord::Base.connection.select_value(sql)
      ActiveRecord::Base.establish_connection(TestingState.db_config["secondary"])
      assert_equal 1, ActiveRecord::Base.connection.select_value(sql)
    end

    it "deletes broken migrations only from the given database when specified" do
      sql = "SELECT COUNT(*) FROM schema_migrations"
      ActiveRecord::Base.establish_connection(TestingState.db_config["primary"])
      assert_equal 2, ActiveRecord::Base.connection.select_value(sql)
      ActiveRecord::Base.establish_connection(TestingState.db_config["secondary"])
      assert_equal 2, ActiveRecord::Base.connection.select_value(sql)
      Rake::Task["actual_db_schema:delete_broken_versions"]
        .invoke("20130906111511 20130906111514", TestingState.db_config["primary"]["database"])
      Rake::Task["actual_db_schema:delete_broken_versions"].reenable
      assert_match(/\[ActualDbSchema\] Migration 20130906111511 was successfully deleted./, TestingState.output)
      assert_match(
        /\[ActualDbSchema\] Error deleting version 20130906111514: Migration is not broken for database #{TestingState.db_config["primary"]["database"]}./, # rubocop:disable Layout/LineLength
        TestingState.output
      )
      ActiveRecord::Base.establish_connection(TestingState.db_config["primary"])
      assert_equal 1, ActiveRecord::Base.connection.select_value(sql)
      ActiveRecord::Base.establish_connection(TestingState.db_config["secondary"])
      assert_equal 2, ActiveRecord::Base.connection.select_value(sql)
    end

    it "prints an error message when the passed version is not broken" do
      Rake::Task["actual_db_schema:delete_broken_versions"].invoke("20130906111512")
      Rake::Task["actual_db_schema:delete_broken_versions"].reenable
      assert_match(
        /\[ActualDbSchema\] Error deleting version 20130906111512: Migration is not broken./, TestingState.output
      )
    end
  end

  describe "when no versions are provided" do
    before { delete_migration_files }

    it "deletes all broken migrations" do
      delete_migration_files
      sql = "SELECT COUNT(*) FROM schema_migrations"
      ActiveRecord::Base.establish_connection(TestingState.db_config["primary"])
      assert_equal 2, ActiveRecord::Base.connection.select_value(sql)
      ActiveRecord::Base.establish_connection(TestingState.db_config["secondary"])
      assert_equal 2, ActiveRecord::Base.connection.select_value(sql)
      Rake::Task["actual_db_schema:delete_broken_versions"].invoke
      Rake::Task["actual_db_schema:delete_broken_versions"].reenable
      assert_match(/\[ActualDbSchema\] All broken versions were successfully deleted./, TestingState.output)
      ActiveRecord::Base.establish_connection(TestingState.db_config["primary"])
      assert_equal 1, ActiveRecord::Base.connection.select_value(sql)
      ActiveRecord::Base.establish_connection(TestingState.db_config["secondary"])
      assert_equal 1, ActiveRecord::Base.connection.select_value(sql)
    end

    it "prints an error message if there is an error during deletion" do
      original_delete_all = ActualDbSchema::Migration.instance_method(:delete_all)
      ActualDbSchema::Migration.define_method(:delete_all) do
        raise StandardError, "Deletion error"
      end
      Rake::Task["actual_db_schema:delete_broken_versions"].invoke
      Rake::Task["actual_db_schema:delete_broken_versions"].reenable
      assert_match(/\[ActualDbSchema\] Error deleting all broken versions: Deletion error/, TestingState.output)
      sql = "SELECT COUNT(*) FROM schema_migrations"
      ActiveRecord::Base.establish_connection(TestingState.db_config["primary"])
      assert_equal 2, ActiveRecord::Base.connection.select_value(sql)
      ActiveRecord::Base.establish_connection(TestingState.db_config["secondary"])
      assert_equal 2, ActiveRecord::Base.connection.select_value(sql)
      ActualDbSchema::Migration.define_method(:delete_all, original_delete_all)
    end
  end

  describe "when there are no broken versions" do
    it "prints a message indicating no broken versions found" do
      Rake::Task["actual_db_schema:delete_broken_versions"].invoke
      Rake::Task["actual_db_schema:delete_broken_versions"].reenable
      assert_match(/No broken versions found/, TestingState.output)
    end
  end

  after do
    utils.clear_db_storage_table(TestingState.db_config)
    ActualDbSchema.config[:migrations_storage] = :file
  end
end
