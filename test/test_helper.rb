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

# Load all files from lib
Dir[File.join(__dir__, "../lib/**/*.rb")].each do |file|
  require file
end

# Initialize I18n for tests (use English for assertion readability)
Ksef::I18n.setup(locale: :en)

