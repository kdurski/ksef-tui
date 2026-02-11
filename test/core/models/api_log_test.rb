# frozen_string_literal: true

require_relative "../../test_helper"

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

  def test_from_http_sanitizes_sensitive_payload
    log = Ksef::Models::ApiLog.from_http(
      timestamp: Time.now,
      http_method: "POST",
      path: "/auth/token/redeem",
      status: 200,
      duration: 0.1,
      request_headers: {"Authorization" => "Bearer very-secret"},
      request_body: {token: "raw-token", password: "raw-password"}.to_json,
      response_headers: {"Set-Cookie" => "sid=abc123"},
      response_body: {accessToken: {token: "access-secret", validUntil: "tomorrow"}}.to_json,
      error: nil
    )

    assert_equal "Bearer [REDACTED]", log.request_headers["Authorization"]
    assert_equal "[REDACTED]", log.response_headers["Set-Cookie"]
    assert_equal "[REDACTED]", JSON.parse(log.request_body)["token"]
    assert_equal "[REDACTED]", JSON.parse(log.request_body)["password"]
    assert_equal "[REDACTED]", JSON.parse(log.response_body)["accessToken"]["token"]
    assert_equal "tomorrow", JSON.parse(log.response_body)["accessToken"]["validUntil"]
  end
end
