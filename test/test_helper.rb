# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

# Load Rails and ActionView for testing
require "rails"
require "action_view"
require "active_support/all"

# Load ViewComponent and our gem
require "view_component"
require "view_component_subtemplates"

require "minitest/autorun"
require "shoulda/context"
