# frozen_string_literal: true

require_relative "../test_helper"

module ActualDbSchema
  module Middlewares
    class SkipPendingMigrationCheckTest < ActiveSupport::TestCase
      test "sets flag for /rails/ subpaths and skips pending migration check" do
        [
          { "PATH_INFO" => "/rails/migrations", "REQUEST_METHOD" => "GET" },
          { "PATH_INFO" => "/rails/phantom_migrations", "REQUEST_METHOD" => "GET" },
          { "PATH_INFO" => "/rails/schema", "REQUEST_METHOD" => "GET" },
          { "PATH_INFO" => "/rails/broken_versions", "REQUEST_METHOD" => "GET" },
          { "PATH_INFO" => "/rails/migrations/123/migrate", "REQUEST_METHOD" => "POST" },
          { "PATH_INFO" => "/rails/migrations/123/rollback", "REQUEST_METHOD" => "POST" }
        ].each do |env|
          ActualDbSchema::Engine.routes.stub(:recognize_path, { controller: "test", action: "index" }) do
            SkipPendingMigrationCheck.new(check_pending_app).call(env)
            assert env["actual_db_schema.skip_pending_check"], "Expected flag for #{env["PATH_INFO"]}"
          end
        end
      end

      test "does not set flag and raises PendingMigrationError for non-engine paths" do
        %w[/ /some/other/path /rails_fake /railsmigrations].each do |path|
          env = { "PATH_INFO" => path, "REQUEST_METHOD" => "GET" }
          ActualDbSchema::Engine.routes.stub(:recognize_path,
                                             proc { raise ActionController::RoutingError, "No route" }) do
            assert_raises ActiveRecord::PendingMigrationError do
              SkipPendingMigrationCheck.new(check_pending_app).call(env)
            end
            assert_nil env["actual_db_schema.skip_pending_check"], "Expected no flag for #{path}"
          end
        end
      end

      private

      def check_pending_app
        lambda do |env|
          raise ActiveRecord::PendingMigrationError unless env["actual_db_schema.skip_pending_check"]

          [200, {}, []]
        end
      end
    end
  end
end
