# frozen_string_literal: true

require_relative "../test_helper"

class ApiLogTest < Minitest::Test
  def test_api_log_success
    log = Ksef::Models::ApiLog.new(status: 200)
    assert log.success?

    log = Ksef::Models::ApiLog.new(status: 201)
    assert log.success?

    log = Ksef::Models::ApiLog.new(status: 299)
    assert log.success?
  end

  def test_api_log_failure
    log = Ksef::Models::ApiLog.new(status: 400)
    refute log.success?

    log = Ksef::Models::ApiLog.new(status: 500)
    refute log.success?

    log = Ksef::Models::ApiLog.new(status: nil)
    refute log.success?
  end
end
