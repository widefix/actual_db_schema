# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2023, by Samuel Williams.

warn "Rack::Handler is deprecated and replaced by Rackup::Handler"
require_relative '../rackup/handler'
module Rack
	Handler = ::Rackup::Handler
end
