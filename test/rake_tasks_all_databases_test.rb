# frozen_string_literal: true

require "test_helper"

describe "multipe db support" do
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
  end

  describe "db:rollback_branches" do
    it "creates the tmp/migrated folder" do
      refute File.exist?(utils.app_file("tmp/migrated"))
      refute File.exist?(utils.app_file("tmp/migrated_migrate_secondary"))
      utils.run_migrations
      assert File.exist?(utils.app_file("tmp/migrated"))
      assert File.exist?(utils.app_file("tmp/migrated_migrate_secondary"))
    end

    it "migrates the migrations" do
      assert_empty utils.applied_migrations(TestingState.db_config)
      utils.run_migrations
      assert_equal(
        %w[20130906111511 20130906111512 20130906111514 20130906111515],
        utils.applied_migrations(TestingState.db_config)
      )
    end

    it "keeps migrated migrations in tmp/migrated folder" do
      utils.run_migrations
      assert_equal(
        %w[
          20130906111511_first_primary.rb
          20130906111512_second_primary.rb
          20130906111514_first_secondary.rb
          20130906111515_second_secondary.rb
        ],
        utils.migrated_files(TestingState.db_config)
      )
    end

    it "rolls back the migrations in the reversed order" do
      utils.prepare_phantom_migrations(TestingState.db_config)
      assert_empty TestingState.down
      utils.run_migrations
      assert_equal %i[second_primary first_primary second_secondary first_secondary], TestingState.down
      assert_empty utils.migrated_files(TestingState.db_config)
    end

    describe "with irreversible migration" do
      before do
        %w[primary secondary].each do |prefix|
          utils.define_migration_file("20130906111513_irreversible_#{prefix}.rb", <<~RUBY, prefix: prefix)
            class Irreversible#{prefix.camelize} < ActiveRecord::Migration[6.0]
              def up
                TestingState.up << :irreversible_#{prefix}
              end

              def down
                raise ActiveRecord::IrreversibleMigration
              end
            end
          RUBY
        end
      end

      it "keeps track of the irreversible migrations" do
        utils.prepare_phantom_migrations(TestingState.db_config)
        assert_equal(
          %i[first_primary second_primary irreversible_primary irreversible_secondary first_secondary second_secondary],
          TestingState.up
        )
        assert_empty ActualDbSchema.failed
        utils.run_migrations
        failed = ActualDbSchema.failed.map { |m| File.basename(m.filename) }
        assert_equal(%w[20130906111513_irreversible_primary.rb 20130906111513_irreversible_secondary.rb], failed)
        assert_equal(
          %w[20130906111513_irreversible_primary.rb 20130906111513_irreversible_secondary.rb],
          utils.migrated_files(TestingState.db_config)
        )
      end
    end
  end

  describe "db:rollback_branches:manual" do
    it "skips migrations if the input is 'n'" do
      utils.prepare_phantom_migrations
      assert_equal %i[first_primary second_primary first_secondary second_secondary], TestingState.up
      assert_empty TestingState.down
      assert_empty ActualDbSchema.failed

      utils.simulate_input("n") do
        Rake::Task["db:rollback_branches:manual"].invoke
        Rake::Task["db:rollback_branches:manual"].reenable
      end
      assert_empty TestingState.down
      assert_equal %i[first_primary second_primary first_secondary second_secondary], TestingState.up
      assert_equal(
        %w[
          20130906111511_first_primary.rb
          20130906111512_second_primary.rb
          20130906111514_first_secondary.rb
          20130906111515_second_secondary.rb
        ],
        utils.migrated_files(TestingState.db_config)
      )
    end

    describe "with irreversible migration" do
      before do
        %w[primary secondary].each do |prefix|
          utils.define_migration_file("20130906111513_irreversible_#{prefix}.rb", <<~RUBY, prefix: prefix)
            class Irreversible#{prefix.camelize} < ActiveRecord::Migration[6.0]
              def up
                TestingState.up << :irreversible_#{prefix}
              end

              def down
                raise ActiveRecord::IrreversibleMigration
              end
            end
          RUBY
        end
      end

      it "keeps track of the irreversible migrations" do
        utils.prepare_phantom_migrations(TestingState.db_config)
        assert_equal(
          %i[first_primary second_primary irreversible_primary irreversible_secondary first_secondary second_secondary],
          TestingState.up
        )
        assert_empty ActualDbSchema.failed
        utils.simulate_input("y") do
          Rake::Task["db:rollback_branches:manual"].invoke
          Rake::Task["db:rollback_branches:manual"].reenable
        end
        failed = ActualDbSchema.failed.map { |m| File.basename(m.filename) }
        assert_equal(%w[20130906111513_irreversible_primary.rb 20130906111513_irreversible_secondary.rb], failed)
        assert_equal(
          %w[20130906111513_irreversible_primary.rb 20130906111513_irreversible_secondary.rb],
          utils.migrated_files(TestingState.db_config)
        )
      end
    end
  end

  describe "db:phantom_migrations" do
    it "shows the list of phantom migrations" do
      ActualDbSchema::Git.stub(:current_branch, "fix-bug") do
        utils.prepare_phantom_migrations(TestingState.db_config)
        Rake::Task["db:phantom_migrations"].invoke
        Rake::Task["db:phantom_migrations"].reenable
        assert_match(/ Status   Migration ID    Branch   Migration File/, TestingState.output)
        assert_match(/---------------------------------------------------/, TestingState.output)
        assert_match(
          %r{   up     20130906111511  fix-bug  tmp/migrated/20130906111511_first_primary.rb},
          TestingState.output
        )
        assert_match(
          %r{   up     20130906111512  fix-bug  tmp/migrated/20130906111512_second_primary.rb},
          TestingState.output
        )
        assert_match(
          %r{   up     20130906111514  fix-bug  tmp/migrated_migrate_secondary/20130906111514_first_secondary.rb},
          TestingState.output
        )
        assert_match(
          %r{   up     20130906111515  fix-bug  tmp/migrated_migrate_secondary/20130906111515_second_secondary.rb},
          TestingState.output
        )
      end
    end
  end
end
