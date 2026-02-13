# frozen_string_literal: true

require "test_helper"

class KsefLoginRequestTest < ActiveSupport::TestCase
  def test_complete_success_sets_tokens_and_status
    request = KsefLoginRequest.create!(
      nip: "1111111111",
      seed_token: "seed-token",
      host: "api.example"
    )

    request.complete_success!(
      access_token: "access-token",
      refresh_token: "refresh-token",
      valid_until: "2026-02-20T10:00:00Z",
      refresh_token_valid_until: "2026-02-21T10:00:00Z"
    )

    request.reload
    assert_predicate request, :succeeded?
    assert_equal "access-token", request.access_token
    assert_equal "2026-02-20T10:00:00Z", request.access_token_valid_until
    assert_not_nil request.completed_at
  end

  def test_complete_failure_sets_error_and_status
    request = KsefLoginRequest.create!(
      nip: "1111111111",
      seed_token: "seed-token",
      host: "api.example"
    )

    request.complete_failure!("boom")

    request.reload
    assert_predicate request, :failed?
    assert_equal "boom", request.error_message
    assert_not_nil request.completed_at
  end
end
