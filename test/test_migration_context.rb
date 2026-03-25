# frozen_string_literal: true

require "test_helper"

describe "ActualDbSchema::MigrationContext#each" do
  let(:utils) do
    TestUtils.new(
      migrations_path: ["db/migrate", "db/migrate_secondary"],
      migrated_path: ["tmp/migrated", "tmp/migrated_migrate_secondary"]
    )
  end

  before do
    utils.reset_database_yml(TestingState.db_config)
    ActiveRecord::Base.configurations = { "test" => TestingState.db_config }
    ActiveRecord::Tasks::DatabaseTasks.database_configuration = { "test" => TestingState.db_config }
    utils.cleanup(TestingState.db_config)
    # Establish connection to primary as the "original" connection before iterating
    ActiveRecord::Base.establish_connection(**TestingState.db_config["primary"])
  end

  it "restores the original connection after iterating over multiple databases" do
    primary_db = File.basename(TestingState.db_config["primary"]["database"])

    # Iterating switches the connection to each database in turn (primary, then secondary)
    ActualDbSchema::MigrationContext.instance.each { |_context| }

    # After iteration, the connection must be restored to the original (primary) database.
    # Without restoration, the connection is left on the last database (secondary), which
    # means any subsequent ActiveRecord queries silently hit the wrong database.
    current_db = File.basename(current_database)
    assert_equal primary_db, current_db,
      "MigrationContext#each must restore the original connection after iteration, " \
      "but was left on '#{current_db}' instead of '#{primary_db}'"
  end

  private

  def current_database
    if ActiveRecord::Base.respond_to?(:connection_db_config)
      ActiveRecord::Base.connection_db_config.database
    else
      ActiveRecord::Base.connection_config[:database]
    end
  end
end
