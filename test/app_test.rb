# frozen_string_literal: true

require_relative 'test_helper'

# Require real app (won't run because $PROGRAM_NAME is 'test')
require_relative '../app'

class AppTest < Minitest::Test
  def setup
    @tui = mock('tui')
    # Stub draw to yield a mock frame
    mock_frame = mock('frame')
    mock_frame.stubs(:area).returns({})
    mock_frame.stubs(:render_widget)
    
    @tui.stubs(:draw).yields(mock_frame)
    @tui.stubs(:style)
    @tui.stubs(:poll_event).returns({ type: :none })
    
    # Stub layout/widget methods to return nil or empty arrays
    @tui.stubs(:layout_split).returns([[], [], [], []])
    @tui.stubs(:constraint_length)
    @tui.stubs(:constraint_fill)
    @tui.stubs(:paragraph)
    @tui.stubs(:block)
    @tui.stubs(:text_span)
    @tui.stubs(:text_line)
    @tui.stubs(:table)
    @tui.stubs(:table_row)

    @key, @cert = generate_test_certificate
    
    # We need a predictable client for mocking
    @client = Ksef::Client.new
    
    # Inject dependencies
    @app = KsefApp.new(client: @client, tui: @tui)
    
    # Reset log for testing
    set_state(:log_entries, [])
  end

  # Helper to access private state
  def state(var)
    @app.instance_variable_get("@#{var}")
  end

  # Helper to set private state (for setup)
  def set_state(var, value)
    @app.instance_variable_set("@#{var}", value)
  end

  # Initialization tests
  def test_initial_state
    assert_equal [], state(:invoices)
    assert_equal 0, state(:selected_index)
    assert_equal :disconnected, state(:status)
    assert_equal 'Press "c" to connect', state(:status_message)
    assert_nil state(:access_token)
    refute state(:show_detail)
  end

  def test_initial_log_is_empty
    assert_equal [], state(:log_entries)
  end

  # Log tests
  def test_log_adds_timestamped_entry
    @app.log('Test message')
    assert_equal 1, state(:log_entries).length
    assert_match(/\[\d{2}:\d{2}:\d{2}\] Test message/, state(:log_entries).first)
  end

  def test_log_limits_entries
    10.times { |i| @app.log("Message #{i}") }
    assert_equal 8, state(:log_entries).length
    assert_match(/Message 9/, state(:log_entries).last)
  end

  # Connect tests
  def test_connect_sets_loading_status
    stub_auth_failure

    @app.send(:connect)
    # After failed auth, status should be disconnected
    assert_equal :disconnected, state(:status)
  end

  def test_connect_success_sets_connected_status
    stub_full_auth_success
    stub_invoices_response([])

    # Need a valid NIP/Token for Auth to proceed past validation
    # Since we mock Auth.new inside connect to take client, we need credentials separate?
    # Actually, KsefApp#connect instantiates `Auth.new(client: @client)`
    # Auth reads ENV by default. We should mock ENV or pass explicit creds if possible.
    # But KsefApp#connect doesn't take args. It relies on ENV.
    # Let's set ENV for the test duration.
    with_env_credentials do
      @app.send(:connect)
    end
    
    assert_equal :connected, state(:status)
    refute_nil state(:access_token)
  end

  def test_connect_failure_logs_error
    stub_auth_failure
    
    with_env_credentials do
      @app.send(:connect)
    end
    
    assert state(:log_entries).any? { |e| e.include?('ERROR') }
  end

  def test_connect_success_fetches_invoices
    stub_full_auth_success
    stub_invoices_response([{ 'ksefNumber' => 'INV-001' }])

    with_env_credentials do
      @app.send(:connect)
    end
    
    assert_equal 1, state(:invoices).length
  end

  # Refresh tests
  def test_refresh_does_nothing_without_token
    set_state(:access_token, nil)
    initial_log_count = state(:log_entries).length

    @app.send(:refresh)
    assert_equal initial_log_count, state(:log_entries).length
  end

  def test_refresh_fetches_invoices_when_authenticated
    set_state(:access_token, 'valid-token')
    stub_invoices_response([{ 'ksefNumber' => 'INV-002' }])

    @app.send(:refresh)
    assert_equal 1, state(:invoices).length
    assert state(:log_entries).any? { |e| e.include?('Refreshing') }
  end

  # Fetch invoices tests
  def test_fetch_invoices_updates_invoice_list
    set_state(:access_token, 'token')
    stub_invoices_response([
      { 'ksefNumber' => 'INV-001' },
      { 'ksefNumber' => 'INV-002' }
    ])

    @app.send(:fetch_invoices)
    assert_equal 2, state(:invoices).length
  end

  def test_fetch_invoices_resets_selection_if_out_of_bounds
    set_state(:access_token, 'token')
    set_state(:selected_index, 5)
    stub_invoices_response([{ 'ksefNumber' => 'INV-001' }])

    @app.send(:fetch_invoices)
    assert_equal 0, state(:selected_index)
  end

  def test_fetch_invoices_keeps_selection_if_valid
    set_state(:access_token, 'token')
    set_state(:selected_index, 1)
    stub_invoices_response([
      { 'ksefNumber' => 'INV-001' },
      { 'ksefNumber' => 'INV-002' },
      { 'ksefNumber' => 'INV-003' }
    ])

    @app.send(:fetch_invoices)
    assert_equal 1, state(:selected_index)
  end

  def test_fetch_invoices_handles_empty_response
    set_state(:access_token, 'token')
    stub_invoices_response([])

    @app.send(:fetch_invoices)
    assert_equal [], state(:invoices)
  end

  def test_fetch_invoices_logs_count
    set_state(:access_token, 'token')
    stub_invoices_response([{ 'ksefNumber' => 'INV-001' }])

    @app.send(:fetch_invoices)
    assert state(:log_entries).any? { |e| e.include?('Fetched 1 invoice(s)') }
  end

  private

  def with_env_credentials
    ENV['KSEF_NIP'] = '1234567890'
    ENV['KSEF_TOKEN'] = 'test-token'
    yield
  ensure
    ENV.delete('KSEF_NIP')
    ENV.delete('KSEF_TOKEN')
  end

  def generate_test_certificate
    key = OpenSSL::PKey::RSA.new(2048)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 1
    cert.subject = OpenSSL::X509::Name.parse('/CN=Test')
    cert.issuer = cert.subject
    cert.public_key = key.public_key
    cert.not_before = Time.now
    cert.not_after = Time.now + 365 * 24 * 3600
    cert.sign(key, OpenSSL::Digest.new('SHA256'))
    [key, cert]
  end

  def stub_auth_failure
    stub_request(:get, %r{/v2/security/public-key-certificates})
      .to_return(status: 200, body: '[]', headers: { 'Content-Type' => 'application/json' })
  end

  def stub_full_auth_success
    stub_request(:get, %r{/v2/security/public-key-certificates})
      .to_return(
        status: 200,
        body: [{ 'usage' => ['KsefTokenEncryption'], 'certificate' => Base64.strict_encode64(@cert.to_der) }].to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    stub_request(:post, %r{/v2/auth/challenge})
      .to_return(
        status: 200,
        body: '{"challenge": "test", "timestamp": "2026-02-09T12:00:00Z", "timestampMs": 1770638400000}',
        headers: { 'Content-Type' => 'application/json' }
      )

    stub_request(:post, %r{/v2/auth/ksef-token})
      .to_return(
        status: 200,
        body: { authenticationToken: { token: 'auth-token' }, referenceNumber: 'ref-123' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    stub_request(:get, %r{/v2/auth/ref-123})
      .to_return(
        status: 200,
        body: '{"status": {"code": 200, "description": "ok"}}',
        headers: { 'Content-Type' => 'application/json' }
      )

    stub_request(:post, %r{/v2/auth/token/redeem})
      .to_return(
        status: 200,
        body: {
          accessToken: { token: 'access-token', validUntil: '2026-02-09T14:00:00Z' },
          refreshToken: { token: 'refresh-token' }
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def stub_invoices_response(invoices)
    stub_request(:post, %r{/v2/invoices/query/metadata})
      .to_return(
        status: 200,
        body: { 'invoices' => invoices }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end
end
