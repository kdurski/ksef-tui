# frozen_string_literal: true

require_relative "../test_helper"

class ClientTest < ActiveSupport::TestCase
  def setup
    @client = Ksef::Client.new(host: "api.ksef.mf.gov.pl")
  end

  def test_initializes_with_default_host
    client = Ksef::Client.new
    assert_equal "api.ksef.mf.gov.pl", client.host
  end

  def test_initializes_with_custom_host
    client = Ksef::Client.new(host: "api-test.ksef.mf.gov.pl")
    assert_equal "api-test.ksef.mf.gov.pl", client.host
  end

  def test_get_request
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/test/path")
      .to_return(
        status: 200,
        body: '{"result": "success"}',
        headers: { "Content-Type" => "application/json" }
      )

    response = @client.get("/test/path")
    assert_equal({ "result" => "success" }, response)
  end

  def test_get_request_preserves_query_string
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/test/path?foo=bar&baz=1")
      .to_return(
        status: 200,
        body: '{"result": "success"}',
        headers: { "Content-Type" => "application/json" }
      )

    response = @client.get("/test/path?foo=bar&baz=1")
    assert_equal({ "result" => "success" }, response)
  end

  def test_get_request_with_token
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/test/path")
      .with(headers: { "Authorization" => "Bearer test-token" })
      .to_return(
        status: 200,
        body: '{"result": "authenticated"}',
        headers: { "Content-Type" => "application/json" }
      )

    response = @client.get("/test/path", access_token: "test-token")
    assert_equal({ "result" => "authenticated" }, response)
  end

  def test_get_request_uses_client_access_token_by_default
    @client.access_token = "stored-token"

    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/test/default-token")
      .with(headers: { "Authorization" => "Bearer stored-token" })
      .to_return(
        status: 200,
        body: '{"result": "authenticated"}',
        headers: { "Content-Type" => "application/json" }
      )

    response = @client.get("/test/default-token")
    assert_equal({ "result" => "authenticated" }, response)
  end

  def test_get_request_can_skip_client_default_token
    @client.access_token = "stored-token"

    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/test/no-token")
      .with { |request| request.headers["Authorization"].nil? }
      .to_return(
        status: 200,
        body: '{"result": "public"}',
        headers: { "Content-Type" => "application/json" }
      )

    response = @client.get("/test/no-token", access_token: nil)
    assert_equal({ "result" => "public" }, response)
  end

  def test_get_xml_request
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/invoices/ksef/ABC123")
      .with(headers: { "Accept" => "application/xml" })
      .to_return(
        status: 200,
        body: "<Invoice>ok</Invoice>",
        headers: { "Content-Type" => "application/xml" }
      )

    response = @client.get_xml("/invoices/ksef/ABC123")
    assert_equal "<Invoice>ok</Invoice>", response
  end

  def test_post_request
    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/test/path")
      .with(
        body: '{"key":"value"}',
        headers: { "Content-Type" => "application/json" }
      )
      .to_return(
        status: 200,
        body: '{"created": true}',
        headers: { "Content-Type" => "application/json" }
      )

    response = @client.post("/test/path", { key: "value" })
    assert_equal({ "created" => true }, response)
  end

  def test_post_request_with_token
    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/test/path")
      .with(
        headers: { "Authorization" => "Bearer my-token" }
      )
      .to_return(
        status: 200,
        body: '{"authenticated": true}',
        headers: { "Content-Type" => "application/json" }
      )

    response = @client.post("/test/path", {}, access_token: "my-token")
    assert_equal({ "authenticated" => true }, response)
  end

  def test_handles_invalid_json
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/bad/json")
      .to_return(status: 500, body: "Internal Server Error")

    response = @client.get("/bad/json")
    assert response.key?("error")
    assert_match(/Invalid JSON/, response["error"])
  end

  def test_handles_empty_response
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/empty")
      .to_return(status: 204, body: "")

    response = @client.get("/empty")
    assert response.key?("error")
  end

  def test_handles_non_hash_json_error_response
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/non-hash-error")
      .to_return(status: 400, body: "[]", headers: { "Content-Type" => "application/json" })

    response = @client.get("/non-hash-error")
    assert_equal 400, response["http_status"]
    assert_equal "HTTP 400", response["error"]
    assert_equal [], response["body"]
  end

  def test_retries_on_server_error
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/flaky")
      .to_return(status: 503, body: "Service Unavailable")
      .to_return(status: 200, body: '{"result": "success"}')

    client = Ksef::Client.new(host: "api.ksef.mf.gov.pl", max_retries: 1)

    client.stub(:sleep, nil) do
      response = client.get("/flaky")
      assert_equal({ "result" => "success" }, response)
    end
  end

  def test_returns_server_error_after_max_retries
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/down")
      .to_return(status: 503, body: '{"error":"downtime"}')

    client = Ksef::Client.new(host: "api.ksef.mf.gov.pl", max_retries: 1)

    client.stub(:sleep, nil) do
      response = client.get("/down")
      # Should perform 2 requests (original + 1 retry)
      assert_requested(:get, "https://api.ksef.mf.gov.pl/v2/down", times: 2)
      assert_equal 503, response["http_status"]
    end
  end

  def test_retries_on_network_error
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/network-issue")
      .to_raise(SocketError)
      .to_return(status: 200, body: '{"result": "recovered"}')

    client = Ksef::Client.new(host: "api.ksef.mf.gov.pl", max_retries: 1)

    client.stub(:sleep, nil) do
      response = client.get("/network-issue")
      assert_equal({ "result" => "recovered" }, response)
    end
  end

  def test_raises_network_error_after_max_retries
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/network-down")
      .to_raise(SocketError)

    client = Ksef::Client.new(host: "api.ksef.mf.gov.pl", max_retries: 1)

    client.stub(:sleep, nil) do
      assert_raises(SocketError) do
        client.get("/network-down")
      end
      assert_requested(:get, "https://api.ksef.mf.gov.pl/v2/network-down", times: 2)
    end
  end

  def test_logs_redacted_authorization_header
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/test/auth")
      .with(headers: { "Authorization" => "Bearer secret-token" })
      .to_return(status: 200, body: "{}")

    logger = Minitest::Mock.new
    logger.expect(:log_api, nil) do |log_entry|
      assert_equal "Bearer [REDACTED]", log_entry.request_headers["Authorization"]
    end

    client = Ksef::Client.new(host: "api.ksef.mf.gov.pl", logger: logger)
    client.get("/test/auth", access_token: "secret-token")

    logger.verify
  end

  def test_logs_redacted_response_body
    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/auth/token/redeem")
      .to_return(
        status: 200,
        body: '{"accessToken":{"token":"secret","validUntil":"tomorrow"},"refreshToken":{"token":"secret-refresh","validUntil":"next-week"}}',
        headers: { "Content-Type" => "application/json" }
      )

    logger = Minitest::Mock.new
    logger.expect(:log_api, nil) do |log_entry|
      # Verify response body redaction
      body = JSON.parse(log_entry.response_body)
      assert_equal "[REDACTED]", body["accessToken"]["token"]
      assert_equal "tomorrow", body["accessToken"]["validUntil"]
      assert_equal "[REDACTED]", body["refreshToken"]["token"]
    end

    client = Ksef::Client.new(host: "api.ksef.mf.gov.pl", logger: logger)
    client.post("/auth/token/redeem")

    logger.verify
  end

  def test_logs_redacted_request_body
    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/auth/ksef-token")
      .to_return(status: 200, body: "{}")

    logger = Minitest::Mock.new
    logger.expect(:log_api, nil) do |log_entry|
      # Verify request body redaction
      body = JSON.parse(log_entry.request_body)
      assert_equal "[REDACTED]", body["encryptedToken"]
    end

    client = Ksef::Client.new(host: "api.ksef.mf.gov.pl", logger: logger)
    client.post("/auth/ksef-token", { encryptedToken: "super-secret" })

    logger.verify
  end

  def test_logs_redacted_response_headers
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/test/response-headers")
      .to_return(
        status: 200,
        body: "{}",
        headers: {
          "Set-Cookie" => "sid=very-secret; HttpOnly",
          "X-Api-Key" => "api-secret",
          "X-Request-Id" => "req-1"
        }
      )

    logger = Minitest::Mock.new
    logger.expect(:log_api, nil) do |log_entry|
      assert_equal "[REDACTED]", log_entry.response_headers["set-cookie"]
      assert_equal "[REDACTED]", log_entry.response_headers["x-api-key"]
      assert_equal "req-1", log_entry.response_headers["x-request-id"]
    end

    client = Ksef::Client.new(host: "api.ksef.mf.gov.pl", logger: logger)
    client.get("/test/response-headers")

    logger.verify
  end

  def test_logs_redacted_generic_sensitive_fields_in_json_body
    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/test/login")
      .to_return(status: 200, body: "{}")

    logger = Minitest::Mock.new
    logger.expect(:log_api, nil) do |log_entry|
      body = JSON.parse(log_entry.request_body)
      assert_equal "alice", body["username"]
      assert_equal "[REDACTED]", body["password"]
      assert_equal "[REDACTED]", body["apiKey"]
      assert_equal "[REDACTED]", body["token"]
    end

    client = Ksef::Client.new(host: "api.ksef.mf.gov.pl", logger: logger)
    client.post("/test/login", {
      username: "alice",
      password: "secret",
      apiKey: "key-123",
      token: "token-123"
    })

    logger.verify
  end

  def test_logs_redacted_bearer_token_in_plain_text_response_body
    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/test/plain")
      .to_return(status: 200, body: "Authorization: Bearer top-secret-token")

    logger = Minitest::Mock.new
    logger.expect(:log_api, nil) do |log_entry|
      assert_includes log_entry.response_body, "[REDACTED]"
      refute_includes log_entry.response_body, "top-secret-token"
    end

    client = Ksef::Client.new(host: "api.ksef.mf.gov.pl", logger: logger)
    client.get("/test/plain")

    logger.verify
  end
end
