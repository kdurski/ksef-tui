# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/test/"
end

require "bundler/setup"
require "minitest/autorun"
require "webmock/minitest"

require "base64"
require "ratatui_ruby/test_helper"

ENV["KSEF_MAX_RETRIES"] = "0"

# Load app without running it
$PROGRAM_NAME = "test"
require_relative "../lib/ksef/client"
require_relative "../lib/ksef/auth"
