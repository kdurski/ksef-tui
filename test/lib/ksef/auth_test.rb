# frozen_string_literal: true

require "test_helper"
class AuthTest < ActiveSupport::TestCase
  def setup
    @client = Ksef::Client.new(host: "api.ksef.mf.gov.pl")
  end

  def test_initializes_with_custom_credentials
    auth = Ksef::Auth.new(client: @client, nip: "1234567890", access_token: "custom-token")
    assert_equal "1234567890", auth.nip
    assert_equal "custom-token", auth.send(:access_token)
  end

  def test_initializes_with_dirty_nip
    auth = Ksef::Auth.new(client: @client, nip: "123-456-78-90", access_token: "token")
    assert_equal "1234567890", auth.nip
  end

  def test_authenticate_returns_nil_when_no_certificate
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/security/public-key-certificates")
      .to_return(
        status: 200,
        body: "[]",
        headers: { "Content-Type" => "application/json" }
      )

    auth = Ksef::Auth.new(client: @client, nip: "1234567890", access_token: "test")
    assert_raises(Ksef::AuthError) { auth.authenticate }
  end

  def test_authenticate_raises_when_auth_fails
    # Mock certificate response
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/security/public-key-certificates")
      .to_return(
        status: 200,
        body: certificates_response.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Mock challenge response
    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/auth/challenge")
      .to_return(
        status: 200,
        body: '{"challenge": "test-challenge", "timestamp": "2026-02-09T12:00:00Z", "timestampMs": 1770638400000}',
        headers: { "Content-Type" => "application/json" }
      )

    # Mock auth failure
    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/auth/ksef-token")
      .to_return(
        status: 401,
        body: '{"error": "unauthorized"}',
        headers: { "Content-Type" => "application/json" }
      )

    auth = Ksef::Auth.new(client: @client, nip: "1234567890", access_token: "test")
    assert_raises(Ksef::AuthError) { auth.authenticate }
  end

  def test_authenticate_raises_when_cert_fetch_returns_error
    client = Ksef::Client.new(host: "api.ksef.mf.gov.pl", max_retries: 0)

    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/security/public-key-certificates")
      .to_return(status: 500, body: '{"error":"internal"}')

    auth = Ksef::Auth.new(client: client, nip: "1234567890", access_token: "test")
    assert_raises(Ksef::AuthError) { auth.authenticate }
  end

  def test_authenticate_raises_when_challenge_returns_error
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/security/public-key-certificates")
      .to_return(status: 200, body: certificates_response.to_json, headers: { "Content-Type" => "application/json" })

    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/auth/challenge")
      .to_return(status: 400, body: '{"error":"bad request"}')

    auth = Ksef::Auth.new(client: @client, nip: "1234567890", access_token: "test")
    assert_raises(Ksef::AuthError) { auth.authenticate }
  end

  def test_authenticate_raises_when_challenge_response_shape_is_invalid
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/security/public-key-certificates")
      .to_return(status: 200, body: certificates_response.to_json, headers: { "Content-Type" => "application/json" })

    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/auth/challenge")
      .to_return(status: 200, body: "[]", headers: { "Content-Type" => "application/json" })

    auth = Ksef::Auth.new(client: @client, nip: "1234567890", access_token: "test")
    error = assert_raises(Ksef::AuthError) { auth.authenticate }
    assert_match(/Challenge response is invalid/, error.message)
  end

  def test_authenticate_raises_when_challenge_timestamp_is_missing
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/security/public-key-certificates")
      .to_return(status: 200, body: certificates_response.to_json, headers: { "Content-Type" => "application/json" })

    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/auth/challenge")
      .to_return(status: 200, body: '{"challenge": "c"}', headers: { "Content-Type" => "application/json" })

    auth = Ksef::Auth.new(client: @client, nip: "1234567890", access_token: "test")
    error = assert_raises(Ksef::AuthError) { auth.authenticate }
    assert_match(/missing timestamp/i, error.message)
  end

  def test_authenticate_raises_when_reference_number_is_missing
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/security/public-key-certificates")
      .to_return(status: 200, body: certificates_response.to_json, headers: { "Content-Type" => "application/json" })

    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/auth/challenge")
      .to_return(status: 200, body: '{"challenge":"c","timestampMs":1770638400000}', headers: { "Content-Type" => "application/json" })

    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/auth/ksef-token")
      .to_return(status: 200, body: '{"authenticationToken":{"token":"auth-token"}}', headers: { "Content-Type" => "application/json" })

    auth = Ksef::Auth.new(client: @client, nip: "1234567890", access_token: "test")
    error = assert_raises(Ksef::AuthError) { auth.authenticate }
    assert_match(/No reference number in response/, error.message)
  end

  def test_authenticate_raises_when_certificate_expired
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/security/public-key-certificates")
      .to_return(
        status: 200,
        body: certificates_response("ksef_public_cert_expired.der").to_json,
        headers: { "Content-Type" => "application/json" }
      )

    auth = Ksef::Auth.new(client: @client, nip: "1234567890", access_token: "test")
    error = assert_raises(Ksef::AuthError) { auth.authenticate }
    assert_match(/expired/, error.message)
  end

  def test_authenticate_raises_when_redemption_fails
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/security/public-key-certificates")
      .to_return(status: 200, body: certificates_response.to_json, headers: { "Content-Type" => "application/json" })

    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/auth/challenge")
      .to_return(status: 200, body: '{"challenge": "c", "timestamp": "2026-02-09T12:00:00Z", "timestampMs": 1770638400000}', headers: { "Content-Type" => "application/json" })

    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/auth/ksef-token")
      .to_return(status: 200, body: '{"referenceNumber": "REF1", "authenticationToken": {"token": "auth-token"}}', headers: { "Content-Type" => "application/json" })

    # Status check succeeds immediately
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/auth/REF1")
      .with(headers: { "Authorization" => "Bearer auth-token" })
      .to_return(status: 200, body: '{"status": {"code": 200}}', headers: { "Content-Type" => "application/json" })

    # Redemption fails
    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/auth/token/redeem")
      .with(headers: { "Authorization" => "Bearer auth-token" })
      .to_return(status: 400, body: '{"error": "redeem failed"}', headers: { "Content-Type" => "application/json" })

    auth = Ksef::Auth.new(client: @client, nip: "123", access_token: "t")
    error = assert_raises(Ksef::AuthError) { auth.authenticate }
    assert_match(/Token redeem failed/, error.message)
  end

  def test_authenticate_raises_when_status_check_has_error
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/security/public-key-certificates")
      .to_return(status: 200, body: certificates_response.to_json, headers: { "Content-Type" => "application/json" })

    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/auth/challenge")
      .to_return(status: 200, body: '{"challenge": "c", "timestamp": "2026-02-09T12:00:00Z", "timestampMs": 1770638400000}', headers: { "Content-Type" => "application/json" })

    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/auth/ksef-token")
      .to_return(status: 200, body: '{"referenceNumber": "REF1", "authenticationToken": {"token": "auth-token"}}', headers: { "Content-Type" => "application/json" })

    # Status check returns error
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/auth/REF1")
      .with(headers: { "Authorization" => "Bearer auth-token" })
      .to_return(status: 200, body: '{"error": "processing failed"}', headers: { "Content-Type" => "application/json" })

    auth = Ksef::Auth.new(client: @client, nip: "123", access_token: "t")
    error = assert_raises(Ksef::AuthError) { auth.authenticate }
    assert_match(/Auth status check failed/, error.message)
  end

  def test_authenticate_returns_tokens_on_success
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/security/public-key-certificates")
      .to_return(status: 200, body: certificates_response.to_json, headers: { "Content-Type" => "application/json" })

    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/auth/challenge")
      .to_return(
        status: 200,
        body: '{"challenge":"ok","timestamp":"2026-02-09T12:00:00Z","timestampMs":1770638400000}',
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/auth/ksef-token")
      .to_return(
        status: 200,
        body: '{"referenceNumber":"REF-SUCCESS","authenticationToken":{"token":"auth-token"}}',
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/auth/REF-SUCCESS")
      .with(headers: { "Authorization" => "Bearer auth-token" })
      .to_return(status: 200, body: '{"status":{"code":200}}', headers: { "Content-Type" => "application/json" })

    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/auth/token/redeem")
      .with(headers: { "Authorization" => "Bearer auth-token" })
      .to_return(
        status: 200,
        body: '{"accessToken":{"token":"access-1","validUntil":"2026-02-09T14:00:00Z"},"refreshToken":{"token":"refresh-1","validUntil":"2026-03-01T10:00:00Z"}}',
        headers: { "Content-Type" => "application/json" }
      )

    result = Ksef::Auth.new(client: @client, nip: "1234567890", access_token: "test").authenticate

    assert_equal "access-1", result[:access_token]
    assert_equal "refresh-1", result[:refresh_token]
    assert_equal "2026-02-09T14:00:00Z", result[:valid_until]
    assert_equal "2026-03-01T10:00:00Z", result[:refresh_token_valid_until]
    assert_equal "access-1", @client.access_token
  end

  def test_authenticate_handles_missing_refresh_token
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/security/public-key-certificates")
      .to_return(status: 200, body: certificates_response.to_json, headers: { "Content-Type" => "application/json" })

    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/auth/challenge")
      .to_return(
        status: 200,
        body: '{"challenge":"ok","timestamp":"2026-02-09T12:00:00Z","timestampMs":1770638400000}',
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/auth/ksef-token")
      .to_return(
        status: 200,
        body: '{"referenceNumber":"REF-NO-REFRESH","authenticationToken":{"token":"auth-token"}}',
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/auth/REF-NO-REFRESH")
      .with(headers: { "Authorization" => "Bearer auth-token" })
      .to_return(status: 200, body: '{"status":{"code":200}}', headers: { "Content-Type" => "application/json" })

    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/auth/token/redeem")
      .with(headers: { "Authorization" => "Bearer auth-token" })
      .to_return(
        status: 200,
        body: '{"accessToken":{"token":"access-2","validUntil":"2026-02-09T14:00:00Z"}}',
        headers: { "Content-Type" => "application/json" }
      )

    result = Ksef::Auth.new(client: @client, nip: "1234567890", access_token: "test").authenticate

    assert_equal "access-2", result[:access_token]
    assert_nil result[:refresh_token]
    assert_equal "2026-02-09T14:00:00Z", result[:valid_until]
    assert_nil result[:refresh_token_valid_until]
  end

  private

  def certificates_response(fixture_name = "ksef_public_cert_valid.der")
    [
      {
        "usage" => [ "KsefTokenEncryption" ],
        "certificate" => Base64.strict_encode64(cert_fixture_bytes(fixture_name))
      }
    ]
  end

  def cert_fixture_bytes(name)
    path = Rails.root.join("test/fixtures/files", name)
    File.binread(path)
  end
end
