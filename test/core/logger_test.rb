# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/ksef/models/api_log"

class LoggerTest < ActiveSupport::TestCase
  def test_entry_rotation
    logger = Ksef::Logger.new(max_size: 2)

    logger.info("One")
    logger.info("Two")
    assert_equal 2, logger.entries.length
    assert_match(/One/, logger.entries[0])

    logger.info("Three")
    assert_equal 2, logger.entries.length
    assert_match(/Two/, logger.entries[0])
    assert_match(/Three/, logger.entries[1])
  end

  def test_api_log_rotation
    logger = Ksef::Logger.new(max_api_logs: 2)

    log1 = Ksef::Models::ApiLog.new(path: "/1")
    log2 = Ksef::Models::ApiLog.new(path: "/2")
    log3 = Ksef::Models::ApiLog.new(path: "/3")

    logger.log_api(log1)
    logger.log_api(log2)
    assert_equal 2, logger.api_logs.length
    assert_equal "/1", logger.api_logs[0].path

    logger.log_api(log3)
    assert_equal 2, logger.api_logs.length
    assert_equal "/2", logger.api_logs[0].path
    assert_equal "/3", logger.api_logs[1].path
  end
end
