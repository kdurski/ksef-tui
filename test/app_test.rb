# frozen_string_literal: true

require_relative 'test_helper'

# Require real app (won't run because $PROGRAM_NAME is 'test')
require_relative '../app'

class AppTest < Minitest::Test
  include RatatuiRuby::TestHelper

  def setup
    # We need a predictable client for mocking
    @client = Ksef::Client.new
    @key, @cert = generate_test_certificate
  end

  # Helper to access private state
  def state(app, var)
    app.instance_variable_get("@#{var}")
  end

  # Helper to set private state
  def set_state(app, var, value)
    app.instance_variable_set("@#{var}", value)
  end

  # Initialization tests
  def test_initial_state
    with_test_terminal do
      app = KsefApp.new(client: @client, tui: RatatuiRuby::TUI.new)
      app.run_once

      assert_equal [], state(app, :invoices)
      assert_equal 0, state(app, :selected_index)
      assert_equal :disconnected, state(app, :status)
      assert_nil state(app, :access_token)
      refute state(app, :show_detail)

      # Verify rendering
      assert_includes buffer_content.join, 'Press "c" to connect'
      assert_includes buffer_content.join, '○ Disconnected'
    end
  end

  # Log tests
  def test_log_adds_timestamped_entry
    with_test_terminal do
      app = KsefApp.new(client: @client, tui: RatatuiRuby::TUI.new)
      app.log('Test message')
      
      assert_equal 2, state(app, :log_entries).length
      assert_match(/\[\d{2}:\d{2}:\d{2}\] Test message/, state(app, :log_entries).last)
      
      app.run_once
      assert_includes buffer_content.join, 'Test message'
    end
  end

  # Connect tests
  def test_connect_sets_loading_status
    stub_auth_failure

    with_test_terminal do
      app = KsefApp.new(client: @client, tui: RatatuiRuby::TUI.new)
      # Trigger connect via private method or key injection?
      # Let's use private method for unit testing logic, 
      # but we can also use key injection for integration testing.
      app.send(:connect)
      
      # After failed auth, status should be disconnected
      assert_equal :disconnected, state(app, :status)
      
      app.run_once
      assert_includes buffer_content.join, 'Connection failed'
    end
  end

  def test_connect_success_sets_connected_status
    stub_full_auth_success
    stub_invoices_response([])

    with_env('KSEF_NIP', '1234567890') do
      with_env('KSEF_TOKEN', 'test-token') do
        with_test_terminal do
          app = KsefApp.new(client: @client, tui: RatatuiRuby::TUI.new)
          app.send(:connect)
          
          assert_equal :connected, state(app, :status)
          refute_nil state(app, :access_token)
          
          app.run_once
          assert_includes buffer_content.join, '● Connected'
        end
      end
    end
  end

  def test_connect_via_keyboard_shortcut
    stub_full_auth_success
    stub_invoices_response([])

    with_env('KSEF_NIP', '1234567890') do
      with_env('KSEF_TOKEN', 'test-token') do
        with_test_terminal do
          app = KsefApp.new(client: @client, tui: RatatuiRuby::TUI.new)
          
          inject_keys('c')
          app.run_once # Process input (updates state)
          app.run_once # Render new state
          
          assert_equal :connected, state(app, :status)
          assert_includes buffer_content.join, '● Connected'
        end
      end
    end
  end

  # Refresh tests
  def test_refresh_fetches_invoices_when_authenticated
    stub_invoices_response([{ 'ksefNumber' => 'INV-002' }])

    with_test_terminal do
      app = KsefApp.new(client: @client, tui: RatatuiRuby::TUI.new)
      set_state(app, :access_token, 'valid-token')
      set_state(app, :status, :connected) # Needed for refresh guard

      inject_keys('r')
      app.run_once # Handle input (refresh)
      app.run_once # Render new data

      assert_equal 1, state(app, :invoices).length
      assert_includes buffer_content.join, 'INV-002'
    end
  end

  # Navigation tests
  def test_navigation
    with_test_terminal do
      app = KsefApp.new(client: @client, tui: RatatuiRuby::TUI.new)
      set_state(app, :access_token, 'token')
      set_state(app, :invoices, [
        { 'ksefNumber' => 'INV-001', 'invoiceNumber' => '1', 'grossAmount' => '100' },
        { 'ksefNumber' => 'INV-002', 'invoiceNumber' => '2', 'grossAmount' => '200' }
      ])
      
      app.run_once
      # Verify invoice 1 is selected (highlighted)
      # Simpler assertion: check index
      assert_equal 0, state(app, :selected_index)

      inject_keys('j') # Down
      app.run_once
      assert_equal 1, state(app, :selected_index)

      inject_keys('k') # Up
      app.run_once
      assert_equal 0, state(app, :selected_index)
    end
  end

  # Detail view tests
  def test_detail_view_toggling
    with_test_terminal do
      app = KsefApp.new(client: @client, tui: RatatuiRuby::TUI.new)
      set_state(app, :invoices, [{ 'ksefNumber' => 'INV-001' }])

      inject_keys(:enter)
      inject_keys(:enter)
      app.run_once # Process input (toggle detail)
      app.run_once # Render detail view
      assert state(app, :show_detail)
      assert_includes buffer_content.join, 'Invoice Details'

      inject_keys(:esc)
      app.run_once # Process input (back to list)
      app.run_once # Render list view
      refute state(app, :show_detail)
      assert_includes buffer_content.join, 'KSeF Invoice Viewer' # Back to main list
    end
  end

  private

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
