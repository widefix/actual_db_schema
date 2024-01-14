# frozen_string_literal: true

module ActualDbSchema
  module Patches
    # Records the migration file into the tmp folder after it's been migrated
    module MigrationProxy
      def migrate(direction)
        super(direction)
        ActualDbSchema::Store.instance.write(filename) if direction == :up
      end
    end
  end
end
