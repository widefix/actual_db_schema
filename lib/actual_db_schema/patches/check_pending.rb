# frozen_string_literal: true

module ActualDbSchema
  module Patches
    # Patches Rails' CheckPending middleware to skip the pending
    # migration check for ActualDbSchema UI routes (/rails/).
    module CheckPending
      def call(env)
        return @app.call(env) if env["actual_db_schema.skip_pending_check"]

        super
      end
    end
  end
end
