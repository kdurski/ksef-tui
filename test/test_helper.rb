# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/test/"
end

require "bundler/setup"
require "minitest/autorun"
require "webmock/minitest"
require "tmpdir"

require "base64"
require "ratatui_ruby/test_helper"

# Load app without running it
$PROGRAM_NAME = "test"

# Load all files from lib
Dir[File.join(__dir__, "../lib/**/*.rb")].each do |file|
  require file
end

test_config = Ksef::Config.new(File.join(Dir.tmpdir, "ksef_global_test_#{Process.pid}.yml"))
test_config.locale = :en
test_config.max_retries = 0
Ksef.config = test_config

# Initialize I18n for tests (use English for assertion readability)
Ksef::I18n.setup(locale: :en)
