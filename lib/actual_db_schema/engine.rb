# frozen_string_literal: true

module ActualDbSchema
  # It isolates the namespace to avoid conflicts with the main application.
  class Engine < ::Rails::Engine
    isolate_namespace ActualDbSchema
  end
end
