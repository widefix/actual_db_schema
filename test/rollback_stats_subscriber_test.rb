# frozen_string_literal: true

require "test_helper"

describe ActualDbSchema::RollbackStatsSubscriber do
  let(:subscriber) { ActualDbSchema::RollbackStatsSubscriber }

  before do
    subscriber.disable!
    subscriber.reset!
    ActualDbSchema.config[:rollback_stats_subscriber_enabled] = false
  end

  after do
    subscriber.disable!
    subscriber.reset!
    ActualDbSchema.config[:rollback_stats_subscriber_enabled] = false
  end

  it "is disabled by default" do
    refute subscriber.enabled?
    assert_equal 0, subscriber.total_rollbacks
  end

  it "collects rollback stats from instrumentation events" do
    subscriber.enable!

    ActiveSupport::Notifications.instrument(
      ActualDbSchema::Instrumentation::ROLLBACK_EVENT,
      version: "20260101010101",
      name: "CreateUsers",
      database: "primary",
      schema: nil,
      branch: "main",
      manual_mode: false
    )

    ActiveSupport::Notifications.instrument(
      ActualDbSchema::Instrumentation::ROLLBACK_EVENT,
      version: "20260101010102",
      name: "CreatePosts",
      database: "primary",
      schema: "tenant_one",
      branch: "main",
      manual_mode: true
    )

    stats = subscriber.stats
    assert_equal 2, stats[:total]
    assert_equal 2, subscriber.total_rollbacks
    assert_equal 2, stats[:by_database]["primary"]
    assert_equal 1, stats[:by_schema]["default"]
    assert_equal 1, stats[:by_schema]["tenant_one"]
    assert_equal 2, stats[:by_branch]["main"]
  end

  it "disables and unsubscribes from events" do
    subscriber.enable!
    subscriber.disable!
    refute subscriber.enabled?

    ActiveSupport::Notifications.instrument(
      ActualDbSchema::Instrumentation::ROLLBACK_EVENT,
      { version: "20260101010101", database: "primary", schema: nil, branch: "main" }
    )

    assert_equal 0, subscriber.total_rollbacks
  end

  it "resets accumulated stats" do
    subscriber.enable!

    ActiveSupport::Notifications.instrument(
      ActualDbSchema::Instrumentation::ROLLBACK_EVENT,
      { version: "20260101010101", database: "primary", schema: nil, branch: "main" }
    )

    assert_equal 1, subscriber.total_rollbacks
    subscriber.reset!
    assert_equal 0, subscriber.total_rollbacks
    assert_equal({}, subscriber.stats[:by_database])
  end

  it "enables subscriber via engine setup when config flag is true" do
    refute subscriber.enabled?

    ActualDbSchema.config[:rollback_stats_subscriber_enabled] = true
    ActualDbSchema::Engine.setup_rollback_stats_subscriber

    assert subscriber.enabled?
  end
end
