# frozen_string_literal: true

require_relative "actual_db_schema/version"

# The main module definition
module ActualDbSchema
  require "actual_db_schema/railtie" if defined?(Rails)
end
