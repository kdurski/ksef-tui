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
      app = KsefApp.new(client: @client)

      assert_empty app.invoices
      assert_instance_of Ksef::Views::Main, app.current_view
      assert_equal 0, app.current_view.selected_index
      assert_equal :disconnected, app.status
      assert_nil app.session
    end
  end

  # Log tests
  def test_log_adds_timestamped_entry
    with_test_terminal do
      app = KsefApp.new(client: @client)
      app.log('Test message')
      
      entries = app.logger.entries
      assert_equal 2, entries.length
      assert_match(/\[\d{2}:\d{2}:\d{2}\] Test message/, entries.last)
    end
  end

  # Connect tests
  def test_connect_sets_loading_status
    stub_auth_failure

    with_test_terminal do
      app = KsefApp.new(client: @client)
      app.send(:connect)
      
      assert_equal :disconnected, app.status
    end
  end

  def test_connect_success_sets_connected_status
    stub_full_auth_success
    stub_invoices_response([])

    with_env('KSEF_NIP', '1234567890') do
      with_env('KSEF_TOKEN', 'test-token') do
        with_test_terminal do
          app = KsefApp.new(client: @client)
          app.send(:connect)
          
          assert_equal :connected, app.status
          refute_nil app.session
          assert_equal 'access-token', app.session.token
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
          app = KsefApp.new(client: @client)
          
          inject_key('c')
          process_event(app)
          
          assert_equal :connected, app.status
        end
      end
    end
  end

  # Refresh tests
  def test_refresh_fetches_invoices_when_authenticated
    stub_invoices_response([{ 'ksefNumber' => 'INV-002' }])

    with_test_terminal do
      app = KsefApp.new(client: @client)
      
      session = Ksef::Session.new(token: 'valid-token', valid_until: Time.now + 3600)
      app.instance_variable_set(:@session, session)
      app.instance_variable_set(:@status, :connected)
      
      inject_key('r')
      process_event(app)
      
      assert_equal 1, app.invoices.length
      assert_equal 'INV-002', app.invoices.first.ksef_number
    end
  end

  def test_refresh_does_nothing_when_disconnected
    with_test_terminal do
      app = KsefApp.new(client: @client)
      
      inject_key('r')
      process_event(app)
      
      assert_empty app.invoices
    end
  end

  # Navigation tests
  def test_navigation_selects_next_invoice
    with_test_terminal do
      app = create_app_with_invoices(2)
      
      inject_key('j')
      process_event(app)
      
      assert_equal 1, app.current_view.selected_index
    end
  end

  def test_navigation_wraps_around_at_end
    with_test_terminal do
      app = create_app_with_invoices(2)
      app.current_view.instance_variable_set(:@selected_index, 1)
      
      inject_key('j')
      process_event(app)
      
      assert_equal 0, app.current_view.selected_index
    end
  end

  def test_navigation_selects_previous_invoice
    with_test_terminal do
      app = create_app_with_invoices(2)
      app.current_view.instance_variable_set(:@selected_index, 1)
      
      inject_key('k')
      process_event(app)
      
      assert_equal 0, app.current_view.selected_index
    end
  end

  def test_down_arrow_navigates
    with_test_terminal do
      app = create_app_with_invoices(2)
      
      inject_key('down')
      process_event(app)
      
      assert_equal 1, app.current_view.selected_index
    end
  end

  def test_up_arrow_navigates
    with_test_terminal do
      app = create_app_with_invoices(2)
      app.current_view.instance_variable_set(:@selected_index, 1)
      
      inject_key('up')
      process_event(app)
      
      assert_equal 0, app.current_view.selected_index
    end
  end

  # Detail view tests
  def test_detail_view_toggling
    with_test_terminal do
      app = create_app_with_invoices(2)
      
      # Open detail view
      inject_key('enter')
      process_event(app)
      
      assert_instance_of Ksef::Views::Detail, app.current_view
      
      # Close detail view
      inject_key('esc')
      process_event(app)
      
      assert_instance_of Ksef::Views::Main, app.current_view
    end
  end

  # Debug view tests
  def test_debug_view_toggle
    with_test_terminal do
      app = KsefApp.new(client: @client)
      
      # Open debug view
      inject_key('D')
      process_event(app)
      
      assert_instance_of Ksef::Views::Debug, app.current_view
    end
  end

  # Quit tests
  def test_quit_with_q_key
    with_test_terminal do
      app = KsefApp.new(client: @client)
      
      inject_key('q')
      result = process_event(app)
      
      assert_equal :quit, result
    end
  end

  def test_quit_with_ctrl_c
    with_test_terminal do
      app = KsefApp.new(client: @client)
      
      # Ctrl+C should quit
      inject_key(:ctrl_c)
      result = process_event(app)
      
      assert_equal :quit, result
    end
  end

  # View stack tests
  def test_push_pop_view
    with_test_terminal do
      app = KsefApp.new(client: @client)
      
      assert_equal 1, app.view_stack.size
      
      debug_view = Ksef::Views::Debug.new(app)
      app.push_view(debug_view)
      
      assert_equal 2, app.view_stack.size
      assert_equal debug_view, app.current_view
      
      app.pop_view
      
      assert_equal 1, app.view_stack.size
      assert_instance_of Ksef::Views::Main, app.current_view
    end
  end

  def test_pop_view_maintains_at_least_one_view
    with_test_terminal do
      app = KsefApp.new(client: @client)
      
      app.pop_view
      app.pop_view
      app.pop_view
      
      assert_equal 1, app.view_stack.size
      refute_nil app.current_view
    end
  end

  # Trigger methods tests
  def test_trigger_connect_starts_background_thread
    stub_full_auth_success
    stub_invoices_response([])
    
    with_env('KSEF_NIP', '1234567890') do
      with_env('KSEF_TOKEN', 'test-token') do
        with_test_terminal do
          app = KsefApp.new(client: @client)
          app.trigger_connect
          
          # Wait for background thread
          sleep 0.1
          
          assert_equal :connected, app.status
        end
      end
    end
  end

  def test_trigger_refresh_starts_background_thread
    stub_invoices_response([{ 'ksefNumber' => 'INV-REFRESH' }])
    
    with_test_terminal do
      app = KsefApp.new(client: @client)
      session = Ksef::Session.new(token: 'valid-token', valid_until: Time.now + 3600)
      app.instance_variable_set(:@session, session)
      app.instance_variable_set(:@status, :connected)
      
      app.trigger_refresh
      
      # Wait for background thread
      sleep 0.1
      
      assert_equal 1, app.invoices.length
    end
  end

  private

  def process_event(app)
    event = RatatuiRuby.poll_event
    app.current_view.handle_input(event)
  end

  def create_app_with_invoices(count)
    app = KsefApp.new(client: @client)
    app.invoices = count.times.map do |i|
      Ksef::Models::Invoice.new({
        'ksefNumber' => "INV-#{i}",
        'seller' => { 'name' => "Seller #{i}" },
        'grossAmount' => "#{100 * (i + 1)}",
        'currency' => 'PLN'
      })
    end
    app
  end

  def stub_auth_failure
    base_url = @client.send(:base_url)
    stub_request(:get, "#{base_url}/security/public-key-certificates")
      .to_return(status: 401, body: { error: 'Unauthorized' }.to_json)
  end

  def stub_full_auth_success
    base_url = "https://#{@client.host}/v2"
    
    # 1. Mock certificate endpoint
    stub_request(:get, "#{base_url}/security/public-key-certificates")
      .to_return(
        status: 200,
        body: [{
          'usage' => ['KsefTokenEncryption'],
          'certificate' => Base64.strict_encode64(@cert.to_der)
        }].to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # 2. Mock challenge endpoint
    stub_request(:post, "#{base_url}/auth/challenge")
      .to_return(
        status: 200,
        body: '{"challenge": "test-challenge", "timestamp": "2026-02-09T12:00:00Z", "timestampMs": 1770638400000}',
        headers: { 'Content-Type' => 'application/json' }
      )

    # 3. Mock auth endpoint
    stub_request(:post, "#{base_url}/auth/ksef-token")
      .to_return(
        status: 200,
        body: {
          authenticationToken: { token: 'auth-token' },
          referenceNumber: 'ref-123'
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # 4. Mock status check endpoint
    stub_request(:get, "#{base_url}/auth/ref-123")
      .to_return(
        status: 200,
        body: '{"status": {"code": 200, "description": "ok"}}',
        headers: { 'Content-Type' => 'application/json' }
      )

    # 5. Mock token redeem endpoint
    stub_request(:post, "#{base_url}/auth/token/redeem")
      .to_return(
        status: 200,
        body: {
          accessToken: { token: 'access-token', validUntil: '2026-12-31T23:59:59Z' },
          refreshToken: { token: 'refresh-token' }
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def stub_invoices_response(invoices)
    base_url = "https://#{@client.host}/v2"
    stub_request(:post, "#{base_url}/invoices/query/metadata")
      .to_return(
        status: 200,
        body: { 'invoices' => invoices }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def generate_test_certificate
    key = OpenSSL::PKey::RSA.new(2048)
    cert = OpenSSL::X509::Certificate.new
    cert.serial = 1
    cert.version = 2
    cert.not_before = Time.now - 3600
    cert.not_after = Time.now + 3600
    cert.subject = OpenSSL::X509::Name.parse('/C=PL/O=Test/CN=Test')
    cert.issuer = cert.subject
    cert.public_key = key.public_key

    cert.sign(key, OpenSSL::Digest.new('SHA256'))
    [key, cert]
  end
end
