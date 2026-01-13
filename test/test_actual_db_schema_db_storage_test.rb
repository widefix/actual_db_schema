# frozen_string_literal: true

require "test_helper"

class TestActualDbSchemaDbStorage < Minitest::Test
  def setup
    ActualDbSchema.config[:migrations_storage] = :db
  end

  def teardown
    ActualDbSchema.config[:migrations_storage] = :file
  end

  def test_that_it_has_a_version_number
    refute_nil ::ActualDbSchema::VERSION
  end
end
