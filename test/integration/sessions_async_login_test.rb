# frozen_string_literal: true

require "test_helper"

class SessionsAsyncLoginTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def setup
    super
    @config_path = File.join(Dir.tmpdir, "sessions_async_login_test_#{Process.pid}_#{object_id}.yml")
    File.write(@config_path, <<~YAML)
      settings:
        default_host: "api.default.example"
      profiles:
        - name: "HENTO (testowe)"
          id: "hento-testowe"
          nip: "1111111111"
          token: "seed-token"
          host: "api-test.example"
    YAML
    Profile.config_file = @config_path
    clear_enqueued_jobs
    clear_performed_jobs
  end

  def teardown
    Profile.config_file = nil
    FileUtils.rm_f(@config_path)
    clear_enqueued_jobs
    clear_performed_jobs
    super
  end

  def test_create_with_profile_enqueues_background_login
    assert_enqueued_with(job: KsefAuthenticateSessionJob) do
      post sessions_path, params: { profile_id: "hento-testowe" }
    end

    login_request = KsefLoginRequest.last
    assert_predicate login_request, :pending?
    assert_equal "HENTO (testowe)", login_request.profile_name
    assert_redirected_to session_path(login_request)
  end

  def test_status_returns_pending_then_finalize_authenticates_session
    post sessions_path, params: { profile_id: "hento-testowe" }
    login_request = KsefLoginRequest.last

    get status_session_path(login_request)
    assert_response :success
    assert_equal "pending", JSON.parse(response.body).fetch("status")

    login_request.complete_success!(
      access_token: "session-token",
      refresh_token: "refresh-token",
      valid_until: "2026-02-20T10:00:00Z",
      refresh_token_valid_until: "2026-02-21T10:00:00Z"
    )

    get finalize_session_path(login_request)
    assert_redirected_to root_path

    follow_redirect!
    assert_response :success
  end

  def test_finalize_redirects_to_login_when_auth_failed
    post sessions_path, params: { profile_id: "hento-testowe" }
    login_request = KsefLoginRequest.last
    login_request.complete_failure!("invalid token")

    get finalize_session_path(login_request)
    assert_redirected_to new_session_path
    assert_equal "Authentication failed: invalid token", flash[:alert]
  end
end
