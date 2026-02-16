# frozen_string_literal: true

require "test_helper"
require_relative "../lib/actual_db_schema/console_migrations"

describe "console migrations (db storage)" do
  let(:utils) { TestUtils.new }

  before do
    ActualDbSchema.config[:migrations_storage] = :db
    utils.clear_db_storage_table
    extend ActualDbSchema::ConsoleMigrations

    utils.reset_database_yml(TestingState.db_config["primary"])
    ActiveRecord::Base.configurations = { "test" => TestingState.db_config["primary"] }
    ActiveRecord::Tasks::DatabaseTasks.database_configuration = { "test" => TestingState.db_config["primary"] }
    ActiveRecord::Base.establish_connection(**TestingState.db_config["primary"])
    utils.cleanup

    utils.define_migration_file("20250124084321_create_users.rb", <<~RUBY)
      class CreateUsers < ActiveRecord::Migration[6.0]
        def change
          create_table :users do |t|
            t.string :name
            t.string :middle_name
            t.timestamps
          end

          add_index :users, :name, name: "index_users_on_name", unique: true
        end
      end
    RUBY
    utils.run_migrations
  end

  after do
    utils.define_migration_file("20250124084323_drop_users.rb", <<~RUBY)
      class DropUsers < ActiveRecord::Migration[6.0]
        def change
          drop_table :users
        end
      end
    RUBY
    utils.run_migrations
    utils.clear_db_storage_table
    ActualDbSchema.config[:migrations_storage] = :file
  end

  it "adds a column to a table" do
    add_column :users, :email, :string
    assert ActiveRecord::Base.connection.column_exists?(:users, :email)
  end

  it "removes a column from a table" do
    remove_column :users, :middle_name
    refute ActiveRecord::Base.connection.column_exists?(:users, :middle_name)
  end

  it "creates and drops a table" do
    refute ActiveRecord::Base.connection.table_exists?(:categories)
    create_table :categories do |t|
      t.string :title
      t.timestamps
    end
    assert ActiveRecord::Base.connection.table_exists?(:categories)

    drop_table :categories
    refute ActiveRecord::Base.connection.table_exists?(:categories)
  end

  it "changes column type" do
    change_column :users, :middle_name, :text
    assert_equal :text, ActiveRecord::Base.connection.columns(:users).find { |c| c.name == "middle_name" }.type
  end

  it "renames a column" do
    rename_column :users, :name, :full_name
    assert ActiveRecord::Base.connection.column_exists?(:users, :full_name)
    refute ActiveRecord::Base.connection.column_exists?(:users, :name)
  end

  it "adds and removes an index" do
    add_index :users, :middle_name, name: "index_users_on_middle_name", unique: true
    assert ActiveRecord::Base.connection.index_exists?(:users, :middle_name, name: "index_users_on_middle_name")

    remove_index :users, name: "index_users_on_middle_name"
    refute ActiveRecord::Base.connection.index_exists?(:users, :middle_name, name: "index_users_on_middle_name")
  end

  it "adds and removes timestamps" do
    remove_timestamps :users
    refute ActiveRecord::Base.connection.column_exists?(:users, :created_at)
    refute ActiveRecord::Base.connection.column_exists?(:users, :updated_at)

    add_timestamps :users
    assert ActiveRecord::Base.connection.column_exists?(:users, :created_at)
    assert ActiveRecord::Base.connection.column_exists?(:users, :updated_at)
  end
end
