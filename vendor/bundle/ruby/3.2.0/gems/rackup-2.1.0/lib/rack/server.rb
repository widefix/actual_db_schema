# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2023, by Samuel Williams.

warn "Rack::Server is deprecated and replaced by Rackup::Server"
require_relative '../rackup/server'
module Rack
	Server = ::Rackup::Server
end
