# frozen_string_literal: true

module ActualDbSchema
  # Provides functionality for formatting terminal output with colors
  module OutputFormatter
    UNICODE_COLORS = {
      red: 31,
      green: 32,
      yellow: 33,
      gray: 90
    }.freeze

    def colorize(text, color)
      code = UNICODE_COLORS.fetch(color, 37)
      "\e[#{code}m#{text}\e[0m"
    end
  end
end
