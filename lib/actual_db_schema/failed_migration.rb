# frozen_string_literal: true

module ActualDbSchema
  FailedMigration = Struct.new(:migration, :exception, :branch, :schema, keyword_init: true) do
    def filename
      migration.filename
    end

    def short_filename
      migration.filename.sub(File.join(Rails.root, "/"), "")
    end
  end
end
