# frozen_string_literal: true

require "test_helper"

describe "single db" do
  let(:utils) { TestUtils.new }

  before do
    utils.reset_database_yml(TestingState.db_config["primary"])
    ActiveRecord::Base.configurations = { "test" => TestingState.db_config["primary"] }
    ActiveRecord::Tasks::DatabaseTasks.database_configuration = { "test" => TestingState.db_config["primary"] }
    ActiveRecord::Base.establish_connection(**TestingState.db_config["primary"])
    utils.cleanup
  end

  describe "db:rollback_branches" do
    it "creates the tmp/migrated folder" do
      refute File.exist?(utils.app_file("tmp/migrated"))
      utils.run_migrations
      assert File.exist?(utils.app_file("tmp/migrated"))
    end

    it "migrates the migrations" do
      assert_empty utils.applied_migrations
      utils.run_migrations
      assert_equal %w[20130906111511 20130906111512], utils.applied_migrations
    end

    it "keeps migrated migrations in tmp/migrated folder" do
      utils.run_migrations
      assert_equal %w[20130906111511_first.rb 20130906111512_second.rb], utils.migrated_files
    end

    it "rolls back the migrations in the reversed order" do
      utils.prepare_phantom_migrations
      assert_empty TestingState.down
      utils.run_migrations
      assert_equal %i[second first], TestingState.down
      assert_match(/\[ActualDbSchema\] Rolling back phantom migration/, TestingState.output)
    end

    describe "with irreversible migration" do
      before do
        utils.define_migration_file("20130906111513_irreversible.rb", <<~RUBY)
          class Irreversible < ActiveRecord::Migration[6.0]
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
        utils.prepare_phantom_migrations
        assert_equal %i[first second irreversible], TestingState.up
        assert_empty ActualDbSchema.failed
        utils.run_migrations
        assert_equal(%w[20130906111513_irreversible.rb], ActualDbSchema.failed.map { |m| File.basename(m.filename) })
        assert_match(/Error encountered during rollback:/, TestingState.output)
        assert_match(/ActiveRecord::IrreversibleMigration/, TestingState.output)
      end
    end

    describe "with irreversible migration is the first" do
      before do
        utils.define_migration_file("20130906111510_irreversible.rb", <<~RUBY)
          class Irreversible < ActiveRecord::Migration[6.0]
            def up
              TestingState.up << :irreversible
            end

            def down
              raise ActiveRecord::IrreversibleMigration
            end
          end
        RUBY
      end

      it "doesn't fail fast and has formatted output" do
        utils.prepare_phantom_migrations
        assert_equal %i[irreversible first second], TestingState.up
        assert_empty ActualDbSchema.failed
        utils.run_migrations
        assert_equal(%w[20130906111510_irreversible.rb], ActualDbSchema.failed.map { |m| File.basename(m.filename) })
        assert_match(/1 phantom migration\(s\) could not be rolled back automatically/, TestingState.output)
      end
    end
  end

  describe "db:rollback_branches:manual" do
    it "rolls back the migrations in the reversed order" do
      utils.prepare_phantom_migrations
      assert_equal %i[first second], TestingState.up
      assert_empty TestingState.down
      assert_empty ActualDbSchema.failed
      utils.simulate_input("y") do
        Rake::Task["db:rollback_branches:manual"].invoke
        Rake::Task["db:rollback_branches:manual"].reenable
      end
      assert_equal %i[second first], TestingState.down
    end

    it "skips migrations if the input is 'n'" do
      utils.prepare_phantom_migrations
      assert_equal %i[first second], TestingState.up
      assert_empty TestingState.down
      assert_empty ActualDbSchema.failed

      utils.simulate_input("n") do
        Rake::Task["db:rollback_branches:manual"].invoke
        Rake::Task["db:rollback_branches:manual"].reenable
      end
      assert_empty TestingState.down
      assert_equal %i[first second], TestingState.up
    end

    describe "with irreversible migration" do
      before do
        utils.define_migration_file("20130906111513_irreversible.rb", <<~RUBY)
          class Irreversible < ActiveRecord::Migration[6.0]
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
        utils.prepare_phantom_migrations
        assert_equal %i[first second irreversible], TestingState.up
        assert_empty ActualDbSchema.failed
        utils.simulate_input("y") do
          Rake::Task["db:rollback_branches:manual"].invoke
          Rake::Task["db:rollback_branches:manual"].reenable
        end
        assert_equal %i[second first], TestingState.down
        assert_equal(%w[20130906111513_irreversible.rb], ActualDbSchema.failed.map { |m| File.basename(m.filename) })
      end
    end
  end

  describe "db:phantom_migrations" do
    it "shows the list of phantom migrations" do
      ActualDbSchema::Git.stub(:current_branch, "fix-bug") do
        utils.prepare_phantom_migrations
        Rake::Task["db:phantom_migrations"].invoke
        Rake::Task["db:phantom_migrations"].reenable
        assert_match(/ Status   Migration ID    Branch   Migration File/, TestingState.output)
        assert_match(/---------------------------------------------------/, TestingState.output)
        assert_match(%r{   up     20130906111511  fix-bug  tmp/migrated/20130906111511_first.rb}, TestingState.output)
        assert_match(%r{   up     20130906111512  fix-bug  tmp/migrated/20130906111512_second.rb}, TestingState.output)
      end
    end
  end
end
