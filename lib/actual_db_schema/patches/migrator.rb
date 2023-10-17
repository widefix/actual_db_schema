# frozen_string_literal: true

module ActualDbSchema
  module Patches
    # Run only one migration that's being rolled back
    module Migrator
      def runnable
        migration = migrations.first # there is only one migration, because we pass only one here
        ran?(migration) ? [migration] : []
      end
    end
  end
end
