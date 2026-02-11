# frozen_string_literal: true

require_relative "../test_helper"

class AuthSuccessTest < Minitest::Test
  def setup
    @client = Ksef::Client.new(host: "api.ksef.mf.gov.pl")
    @key, @cert = generate_test_certificate
  end

  def test_full_authentication_flow_success
    # 1. Mock certificate endpoint
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/security/public-key-certificates")
      .to_return(
        status: 200,
        body: certificates_response(@cert).to_json,
        headers: {"Content-Type" => "application/json"}
      )

    # 2. Mock challenge endpoint
    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/auth/challenge")
      .to_return(
        status: 200,
        body: '{"challenge": "test-challenge-123", "timestamp": "2026-02-09T12:00:00Z", "timestampMs": 1770638400000}',
        headers: {"Content-Type" => "application/json"}
      )

    # 3. Mock auth endpoint
    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/auth/ksef-token")
      .to_return(
        status: 200,
        body: {
          authenticationToken: {token: "auth-token-abc"},
          referenceNumber: "ref-123"
        }.to_json,
        headers: {"Content-Type" => "application/json"}
      )

    # 4. Mock status check endpoint
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/auth/ref-123")
      .to_return(
        status: 200,
        body: '{"status": {"code": 200, "description": "ok"}}',
        headers: {"Content-Type" => "application/json"}
      )

    # 5. Mock token redeem endpoint
    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/auth/token/redeem")
      .to_return(
        status: 200,
        body: {
          accessToken: {token: "access-token-xyz", validUntil: "2026-02-09T14:00:00Z"},
          refreshToken: {token: "refresh-token-abc"}
        }.to_json,
        headers: {"Content-Type" => "application/json"}
      )

    auth = Ksef::Auth.new(client: @client, nip: "1234567890", access_token: "test-token")
    result = auth.authenticate

    refute_nil result
    assert_equal "access-token-xyz", result[:access_token]
    assert_equal "refresh-token-abc", result[:refresh_token]
    assert_equal "2026-02-09T14:00:00Z", result[:valid_until]
  end

  def test_authentication_fails_on_status_check_error
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/security/public-key-certificates")
      .to_return(
        status: 200,
        body: certificates_response(@cert).to_json,
        headers: {"Content-Type" => "application/json"}
      )

    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/auth/challenge")
      .to_return(
        status: 200,
        body: '{"challenge": "test-challenge", "timestamp": "2026-02-09T12:00:00Z", "timestampMs": 1770638400000}',
        headers: {"Content-Type" => "application/json"}
      )

    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/auth/ksef-token")
      .to_return(
        status: 200,
        body: {
          authenticationToken: {token: "auth-token"},
          referenceNumber: "ref-456"
        }.to_json,
        headers: {"Content-Type" => "application/json"}
      )

    # Status check returns error
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/auth/ref-456")
      .to_return(
        status: 200,
        body: '{"status": {"code": 401, "description": "unauthorized"}}',
        headers: {"Content-Type" => "application/json"}
      )

    auth = Ksef::Auth.new(client: @client, nip: "1234567890", access_token: "test-token")
    assert_raises(Ksef::AuthError) { auth.authenticate }
  end

  def test_authentication_fails_on_redeem_error
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/security/public-key-certificates")
      .to_return(
        status: 200,
        body: certificates_response(@cert).to_json,
        headers: {"Content-Type" => "application/json"}
      )

    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/auth/challenge")
      .to_return(
        status: 200,
        body: '{"challenge": "test-challenge", "timestamp": "2026-02-09T12:00:00Z", "timestampMs": 1770638400000}',
        headers: {"Content-Type" => "application/json"}
      )

    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/auth/ksef-token")
      .to_return(
        status: 200,
        body: {
          authenticationToken: {token: "auth-token"},
          referenceNumber: "ref-789"
        }.to_json,
        headers: {"Content-Type" => "application/json"}
      )

    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/auth/ref-789")
      .to_return(
        status: 200,
        body: '{"status": {"code": 200, "description": "ok"}}',
        headers: {"Content-Type" => "application/json"}
      )

    # Token redeem fails
    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/auth/token/redeem")
      .to_return(
        status: 401,
        body: '{"error": "invalid token"}',
        headers: {"Content-Type" => "application/json"}
      )

    auth = Ksef::Auth.new(client: @client, nip: "1234567890", access_token: "test-token")
    assert_raises(Ksef::AuthError) { auth.authenticate }
  end

  private

  def generate_test_certificate
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
    [key, cert]
  end

  def certificates_response(cert)
    [
      {
        "usage" => ["KsefTokenEncryption"],
        "certificate" => Base64.strict_encode64(cert.to_der)
      }
    ]
  end
end
