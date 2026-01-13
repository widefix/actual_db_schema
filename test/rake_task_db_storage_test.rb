# frozen_string_literal: true

require "test_helper"

describe "db storage" do
  let(:utils) { TestUtils.new }

  before do
    utils.reset_database_yml(TestingState.db_config["primary"])
    ActiveRecord::Base.configurations = { "test" => TestingState.db_config["primary"] }
    ActiveRecord::Tasks::DatabaseTasks.database_configuration = { "test" => TestingState.db_config["primary"] }
    ActiveRecord::Base.establish_connection(**TestingState.db_config["primary"])
    utils.clear_db_storage_table
    ActualDbSchema.config[:migrations_storage] = :db
    utils.cleanup
  end

  after do
    utils.clear_db_storage_table
    ActualDbSchema.config[:migrations_storage] = :file
  end

  it "stores migrated files in the database" do
    utils.run_migrations

    conn = ActiveRecord::Base.connection
    assert conn.table_exists?("actual_db_schema_migrations")

    rows = conn.select_all("select version, filename from actual_db_schema_migrations").to_a
    versions = rows.map { |row| row["version"] }.sort
    assert_equal %w[20130906111511 20130906111512], versions
  end

  it "rolls back phantom migrations and clears stored records" do
    utils.prepare_phantom_migrations
    assert_empty TestingState.down

    utils.run_migrations
    assert_equal %i[second first], TestingState.down

    rows = ActiveRecord::Base.connection.select_all("select version from actual_db_schema_migrations").to_a
    assert_empty rows
  end

  it "materializes migration files from the database" do
    utils.run_migrations
    FileUtils.rm_rf(utils.app_file("tmp/migrated"))

    ActualDbSchema::Store.instance.materialize_all
    assert_equal %w[20130906111511_first.rb 20130906111512_second.rb], utils.migrated_files
  end

end
