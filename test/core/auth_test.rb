# frozen_string_literal: true

require_relative "../test_helper"

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
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/security/public-key-certificates")
      .to_return(status: 500, body: '{"error":"internal"}')

    auth = Ksef::Auth.new(client: @client, nip: "1234567890", access_token: "test")
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
    key = OpenSSL::PKey::RSA.new(2048)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 1
    cert.subject = OpenSSL::X509::Name.parse("/CN=Expired")
    cert.issuer = cert.subject
    cert.public_key = key.public_key
    cert.not_before = Time.now - 365 * 24 * 3600 * 2
    cert.not_after = Time.now - 365 * 24 * 3600 # Expired 1 year ago
    cert.sign(key, OpenSSL::Digest.new("SHA256"))

    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/security/public-key-certificates")
      .to_return(
        status: 200,
        body: [ { "usage" => [ "KsefTokenEncryption" ], "certificate" => Base64.strict_encode64(cert.to_der) } ].to_json,
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

  private

  def certificates_response
    # Generate a self-signed cert for testing
    key = OpenSSL::PKey::RSA.new(2048)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 1
    cert.subject = OpenSSL::X509::Name.parse("/CN=Test")
    cert.issuer = cert.subject
    cert.public_key = key.public_key
    cert.not_before = Time.now
    cert.not_after = Time.now + 365 * 24 * 3600
    cert.sign(key, OpenSSL::Digest.new("SHA256"))

    [
      {
        "usage" => [ "KsefTokenEncryption" ],
        "certificate" => Base64.strict_encode64(cert.to_der)
      }
    ]
  end
end
