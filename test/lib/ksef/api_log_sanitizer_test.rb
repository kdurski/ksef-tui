# frozen_string_literal: true

require "test_helper"
class ApiLogSanitizerTest < ActiveSupport::TestCase
  def test_sanitize_headers_redacts_sensitive_values
    headers = {
      "Authorization" => "Bearer secret-token",
      "X-Api-Key" => "top-secret",
      "X-Trace-Id" => "trace-123"
    }

    result = Ksef::ApiLogSanitizer.sanitize_headers(headers)

    assert_equal "Bearer [REDACTED]", result["Authorization"]
    assert_equal "[REDACTED]", result["X-Api-Key"]
    assert_equal "trace-123", result["X-Trace-Id"]
  end

  def test_sanitize_headers_handles_nil
    assert_equal({}, Ksef::ApiLogSanitizer.sanitize_headers(nil))
  end

  def test_sanitize_body_redacts_json_payload
    payload = {
      token: "abc123",
      nested: {
        authorization: "Bearer super-secret",
        note: "visible"
      }
    }

    sanitized = Ksef::ApiLogSanitizer.sanitize_body(payload.to_json)
    parsed = JSON.parse(sanitized)

    assert_equal "[REDACTED]", parsed["token"]
    assert_equal "[REDACTED]", parsed["nested"]["authorization"]
    assert_equal "visible", parsed["nested"]["note"]
  end

  def test_sanitize_body_redacts_plain_text
    input = "token=abc123 Authorization: Bearer secret-token"
    output = Ksef::ApiLogSanitizer.sanitize_body(input)

    assert_includes output, "token=[REDACTED]"
    assert_includes output, "Authorization: [REDACTED]"
  end

  def test_sanitize_body_returns_nil_for_blank_input
    assert_nil Ksef::ApiLogSanitizer.sanitize_body(nil)
    assert_nil Ksef::ApiLogSanitizer.sanitize_body("")
  end
end
