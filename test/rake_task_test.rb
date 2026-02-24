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
    def collect_rollback_events
      events = []
      subscriber = ActiveSupport::Notifications.subscribe(ActualDbSchema::Instrumentation::ROLLBACK_EVENT) do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      yield events
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

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
      assert_empty utils.migrated_files
    end

    it "emits one instrumentation event per successful rollback" do
      utils.prepare_phantom_migrations
      events = nil

      collect_rollback_events do |captured_events|
        utils.run_migrations
        events = captured_events
      end

      assert_equal 2, events.size
      assert_equal(%w[20130906111512 20130906111511], events.map { |event| event.payload[:version] })
      assert_equal([false, false], events.map { |event| event.payload[:manual_mode] })
      assert_equal([utils.primary_database, utils.primary_database], events.map { |event| event.payload[:database] })
      assert_equal([nil, nil], events.map { |event| event.payload[:schema] })
      assert_equal(%w[main main], events.map { |event| event.payload[:branch] })
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
        assert_equal %w[20130906111513_irreversible.rb], utils.migrated_files
      end

      it "does not emit instrumentation for failed rollbacks" do
        utils.prepare_phantom_migrations
        events = nil

        collect_rollback_events do |captured_events|
          utils.run_migrations
          events = captured_events
        end

        assert_equal(%w[20130906111512 20130906111511], events.map { |event| event.payload[:version] })
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
        assert_match(/Try these steps to fix and move forward:/, TestingState.output)
        assert_match(/Below are the details of the problematic migrations:/, TestingState.output)
        assert_match(%r{File: tmp/migrated/20130906111510_irreversible.rb}, TestingState.output)
        assert_equal %w[20130906111510_irreversible.rb], utils.migrated_files
      end
    end

    describe "with acronyms defined" do
      before do
        utils.define_migration_file("20241218064344_ts360.rb", <<~RUBY)
          class Ts360 < ActiveRecord::Migration[6.0]
            def up
              TestingState.up << :ts360
            end

            def down
              TestingState.down << :ts360
            end
          end
        RUBY
      end

      it "rolls back the phantom migrations without failing" do
        utils.prepare_phantom_migrations
        assert_equal %i[first second ts360], TestingState.up
        assert_empty ActualDbSchema.failed
        utils.define_acronym("TS360")
        utils.run_migrations
        assert_equal %i[ts360 second first], TestingState.down
        assert_empty ActualDbSchema.failed
        assert_empty utils.migrated_files
      end
    end

    describe "with custom migrated folder" do
      before do
        ActualDbSchema.configure { |config| config.migrated_folder = Rails.root.join("custom", "migrated") }
      end

      after do
        utils.remove_app_dir("custom/migrated")
        ActualDbSchema.configure { |config| config.migrated_folder = nil }
      end

      it "creates the custom migrated folder" do
        refute File.exist?(utils.app_file("custom/migrated"))
        utils.run_migrations
        assert File.exist?(utils.app_file("custom/migrated"))
      end

      it "keeps migrated migrations in the custom migrated folder" do
        utils.run_migrations
        assert_equal %w[20130906111511_first.rb 20130906111512_second.rb], utils.migrated_files
      end

      it "rolls back the migrations in the reversed order" do
        utils.prepare_phantom_migrations
        assert_empty TestingState.down
        utils.run_migrations
        assert_equal %i[second first], TestingState.down
        assert_match(/\[ActualDbSchema\] Rolling back phantom migration/, TestingState.output)
        assert_empty utils.migrated_files
      end
    end

    describe "when app is not a git repository" do
      it "doesn't show an error message" do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            _out, err = capture_subprocess_io do
              utils.prepare_phantom_migrations
            end

            refute_match("fatal: not a git repository", err)
            assert_equal "unknown", ActualDbSchema::Git.current_branch
          end
        end
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
      assert_empty utils.migrated_files
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
      assert_equal %w[20130906111511_first.rb 20130906111512_second.rb], utils.migrated_files
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
        assert_equal %w[20130906111513_irreversible.rb], utils.migrated_files
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
