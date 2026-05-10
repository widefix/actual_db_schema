# frozen_string_literal: true

module ActualDbSchema
  module Middlewares
    # Middleware that skips the pending migration check for ActualDbSchema UI routes.
    # This allows accessing /rails/ paths even when there are pending migrations.
    class SkipPendingMigrationCheck
      def initialize(app)
        @app = app
      end

      def call(env)
        if actual_db_schema_path?(env["PATH_INFO"], env["REQUEST_METHOD"])
          env["actual_db_schema.skip_pending_check"] = true
        end
        @app.call(env)
      end

      private

      def actual_db_schema_path?(path, method)
        return false unless path.start_with?(engine_mount_path)

        ActualDbSchema::Engine.routes.recognize_path(
          path.sub(engine_mount_path, "") || "/",
          method: method
        )

        true
      rescue ActionController::RoutingError
        false
      end

      def engine_mount_path
        @engine_mount_path ||= ActualDbSchema::Engine.routes.find_script_name({})
      end
    end
  end
end
