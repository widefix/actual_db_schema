# frozen_string_literal: true

%w[6.0 6.1 7.0 7.1].each do |version|
  appraise "rails.#{version}" do
    gem "activerecord", "~> #{version}.0"
    gem "activesupport", "~> #{version}.0"
  end
end
