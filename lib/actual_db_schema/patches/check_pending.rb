# frozen_string_literal: true

module ActualDbSchema
  module Patches
    # Skip Rails pending migration checks only for ActualDbSchema migrations UI paths.
    module CheckPending
      MIGRATIONS_UI_PATHS = [
        %r{\A/rails/migrations(?:\z|/)},
        %r{\A/rails/migration(?:\z|/)}
      ].freeze

      def call(env)
        return @app.call(env) if migrations_ui_request?(env)

        super
      end

      private

      def migrations_ui_request?(env)
        path = env["PATH_INFO"] || env["REQUEST_PATH"] || env["ORIGINAL_FULLPATH"]&.split("?")&.first
        return false if path.to_s.empty?

        MIGRATIONS_UI_PATHS.any? { |pattern| pattern.match?(path) }
      end
    end
  end
end
