# frozen_string_literal: true

require_relative "actual_db_schema/version"

# The main module definition
module ActualDbSchema
  raise NotImplementedError, "ActualDbSchema is only supported in Rails" unless defined?(Rails)

  require "railtie"

  class << self
    attr_accessor :config
  end

  self.config = {
    enabled: Rails.env.development?
  }
end
