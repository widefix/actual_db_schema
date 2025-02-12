# frozen_string_literal: true

module ActualDbSchema
  # Controller to display the database schema diff.
  class SchemaController < ActionController::Base
    protect_from_forgery with: :exception
    skip_before_action :verify_authenticity_token

    def index; end

    private

    helper_method def schema_diff_html
      schema_diff = ActualDbSchema::SchemaDiffHtml.new("db/schema.rb", "db/migrate")
      schema_diff.render_html(params[:table])
    end
  end
end
