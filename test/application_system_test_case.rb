# frozen_string_literal: true

require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  self.use_transactional_tests = false

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    options.add_argument("--disable-search-engine-choice-screen")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--no-sandbox")
    options.add_argument("--window-size=1400,1400")
    options.binary = ENV["CHROME_BIN"] if ENV["CHROME_BIN"].present?
  end
end
