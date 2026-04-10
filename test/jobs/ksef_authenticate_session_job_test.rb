# frozen_string_literal: true

require "test_helper"

class KsefAuthenticateSessionJobTest < ActiveJob::TestCase
  def test_marks_login_request_as_succeeded
    login_request = KsefLoginRequest.create!(
      nip: "1111111111",
      seed_token: "seed-token",
      host: "api.example"
    )

    auth = Minitest::Mock.new
    auth.expect(:authenticate, {
      access_token: "access-token",
      refresh_token: "refresh-token",
      valid_until: "2026-02-20T10:00:00Z",
      refresh_token_valid_until: "2026-02-21T10:00:00Z"
    })

    Ksef::Client.stub(:new, Object.new) do
      Ksef::Auth.stub(:new, auth) do
        KsefAuthenticateSessionJob.perform_now(login_request.id)
      end
    end

    auth.verify
    login_request.reload

    assert_predicate login_request, :succeeded?
    assert_equal "access-token", login_request.access_token
  end

  def test_marks_login_request_as_failed_on_auth_error
    login_request = KsefLoginRequest.create!(
      nip: "1111111111",
      seed_token: "seed-token",
      host: "api.example"
    )

    failing_auth = Object.new
    def failing_auth.authenticate
      raise Ksef::AuthError, "invalid token"
    end

    Ksef::Client.stub(:new, Object.new) do
      Ksef::Auth.stub(:new, failing_auth) do
        KsefAuthenticateSessionJob.perform_now(login_request.id)
      end
    end

    login_request.reload

    assert_predicate login_request, :failed?
    assert_equal "invalid token", login_request.error_message
  end
end
