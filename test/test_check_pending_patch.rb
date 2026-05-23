# frozen_string_literal: true

require "test_helper"

class CheckPendingBaseForTest
  attr_reader :super_calls

  def initialize
    @app = ->(_env) { :app_called }
    @super_calls = 0
  end

  def call(_env)
    @super_calls += 1
    :super_called
  end
end

class CheckPendingWithPatchForTest < CheckPendingBaseForTest
  prepend ActualDbSchema::Patches::CheckPending
end

describe "ActualDbSchema::Patches::CheckPending" do
  let(:patched_instance) { CheckPendingWithPatchForTest.new }

  it "prepends the patch to ActiveRecord::Migration::CheckPending" do
    assert_includes ActiveRecord::Migration::CheckPending.ancestors, ActualDbSchema::Patches::CheckPending
  end

  it "bypasses pending check for migrations index path" do
    result = patched_instance.call("PATH_INFO" => "/rails/migrations")

    assert_equal :app_called, result
    assert_equal 0, patched_instance.super_calls
  end

  it "bypasses pending check for migration member actions path" do
    result = patched_instance.call("PATH_INFO" => "/rails/migration/20260101010101/migrate")

    assert_equal :app_called, result
    assert_equal 0, patched_instance.super_calls
  end

  it "keeps default pending check behavior for unrelated paths" do
    result = patched_instance.call("PATH_INFO" => "/rails/phantom_migrations")

    assert_equal :super_called, result
    assert_equal 1, patched_instance.super_calls
  end
end
