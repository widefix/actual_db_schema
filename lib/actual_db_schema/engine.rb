# frozen_string_literal: true

module ActualDbSchema
  # It isolates the namespace to avoid conflicts with the main application.
  class Engine < ::Rails::Engine
    isolate_namespace ActualDbSchema

    initializer "actual_db_schema.append_routes", after: "add_routing_paths" do |app|
      app.routes.append do
        mount ActualDbSchema::Engine => "/actual_db_schema"
      end
    end

    initializer "actual_db_schema.assets.precompile" do |app|
      app.config.assets.precompile += %w[actual_db_schema/styles.css]
    end
  end
end
