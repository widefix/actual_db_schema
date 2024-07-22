# frozen_string_literal: true

module ActualDbSchema
  # It isolates the namespace to avoid conflicts with the main application.
  class Engine < ::Rails::Engine
    isolate_namespace ActualDbSchema

    initializer "actual_db_schema.initialize" do |app|
      if ActualDbSchema.config[:ui_enabled]
        app.routes.append do
          mount ActualDbSchema::Engine => "/rails"
        end

        app.config.assets.precompile += %w[styles.css application.js]
      end
    end
  end
end
