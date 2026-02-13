# frozen_string_literal: true

require_relative "../test_helper"

# Require real app (won't run because $PROGRAM_NAME is 'test')
require_relative "../../lib/ksef/tui/app"

class AppTest < ActiveSupport::TestCase
  def self.test_certificate
    @test_certificate ||= begin
      key = OpenSSL::PKey::RSA.new(1024)
      cert = OpenSSL::X509::Certificate.new
      cert.serial = 1
      cert.version = 2
      cert.not_before = Time.now - 3600
      cert.not_after = Time.now + 3600
      cert.subject = OpenSSL::X509::Name.parse("/C=PL/O=Test/CN=Test")
      cert.issuer = cert.subject
      cert.public_key = key.public_key
      cert.sign(key, OpenSSL::Digest.new("SHA256"))
      cert
    end
  end

  def setup
    # We need a predictable client for mocking
    @logger = Ksef::Logger.new
    @config = build_test_config
    @client = Ksef::Client.new(host: "api.ksef.mf.gov.pl", logger: @logger, config: @config)
    Ksef::I18n.locale = :en
  end

  # Helper to access private state
  def state(app, var)
    app.instance_variable_get("@#{var}")
  end

  # Helper to set private state
  def set_state(app, var, value)
    app.instance_variable_set("@#{var}", value)
  end

  # Helper to create app and keep locale consistent for tests
  def create_app(**kwargs)
    app = Ksef::Tui::App.new(client: @client, config: @config, **kwargs)
    Ksef::I18n.locale = :en
    app
  end

  # Initialization tests
  def test_initial_state
    with_test_terminal do
      app = create_app

      assert_empty app.invoices
      assert_instance_of Ksef::Tui::Views::Main, app.current_view
      assert_equal 0, app.current_view.selected_index
      assert_equal :disconnected, app.status
      assert_nil app.session
    end
  end

  def test_initialize_with_profile_name_loads_selected_profile
    with_test_terminal do
      config = build_test_config
      config.profiles << Ksef::Models::Profile.new(
        name: "Other",
        nip: "2222222222",
        token: "other-token",
        host: "ksef-test.mf.gov.pl"
      )
      app = Ksef::Tui::App.new("Other", config: config)

      assert_equal "Other", app.current_profile.name
      assert_equal "ksef-test.mf.gov.pl", app.client.host
      assert_instance_of Ksef::Tui::Views::Main, app.current_view
    end
  end

  def test_initialize_with_missing_profile_exits
    with_test_terminal do
      config = build_test_config
      out, = capture_io do
        error = assert_raises(SystemExit) { Ksef::Tui::App.new("Missing", config: config) }
        assert_equal 1, error.status
      end
      assert_includes out, "Profile not found: Missing"
    end
  end

  def test_initialize_shows_profile_selector_when_profiles_exist_without_current_profile
    with_test_terminal do
      config = build_test_config
      config.default_profile_name = nil
      config.current_profile_name = nil

      app = Ksef::Tui::App.new(nil, config: config)
      assert_instance_of Ksef::Tui::Views::ProfileSelector, app.current_view
    end
  end

  def test_initialize_without_profiles_exits
    with_test_terminal do
      config = Ksef::Config.new(File.join(Dir.tmpdir, "ksef_empty_#{Process.pid}_#{object_id}.yml"))
      config.locale = :en
      config.profiles = []
      config.default_profile_name = nil
      config.current_profile_name = nil

      out, = capture_io do
        error = assert_raises(SystemExit) { Ksef::Tui::App.new(nil, config: config) }
        assert_equal 1, error.status
      end
      assert_includes out, "Please create a config file at ~/.ksef.yml"
    end
  end

  # Log tests
  def test_log_adds_timestamped_entry
    with_test_terminal do
      app = create_app
      app.log("Test message")

      entries = app.logger.entries
      assert_equal 2, entries.length
      assert_match(/\[\d{2}:\d{2}:\d{2}\] Test message/, entries.last)
    end
  end

  # Connect tests
  def test_connect_sets_loading_status
    stub_auth_failure

    with_test_terminal do
      app = create_app
      app.send(:connect)

      assert_equal :disconnected, app.status
    end
  end

  def test_connect_success_sets_connected_status
    stub_full_auth_success
    stub_invoices_response([])

    with_test_terminal do
      app = create_app
      app.send(:connect)

      assert_equal :connected, app.status
      refute_nil app.session
      assert_equal "access-token", app.session.access_token
    end
  end

  def test_connect_via_keyboard_shortcut
    stub_full_auth_success
    stub_invoices_response([])

    with_test_terminal do
      app = create_app

      inject_key("c")
      process_event(app)

      assert_equal :connected, app.status
    end
  end

  # Refresh tests
  def test_refresh_fetches_invoices_when_authenticated
    stub_invoices_response([ { "ksefNumber" => "INV-002" } ])

    with_test_terminal do
      app = create_app

      session = Ksef::Session.new(
        access_token: "valid-token",
        access_token_valid_until: Time.now + 3600
      )
      app.instance_variable_set(:@session, session)
      app.instance_variable_set(:@status, :connected)

      inject_key("r")
      process_event(app)

      assert_equal 1, app.invoices.length
      assert_equal "INV-002", app.invoices.first.ksef_number
    end
  end

  def test_refresh_does_nothing_when_disconnected
    with_test_terminal do
      app = create_app

      inject_key("r")
      process_event(app)

      assert_empty app.invoices
    end
  end

  def test_connect_handles_auth_error
    # We can mock this by making the cert fetch failed
    stub_request(:get, /.*\/security\/public-key-certificates/)
      .to_return(status: 500, body: '{"error":"internal"}')

    with_test_terminal do
      app = create_app
      app.send(:connect)

      assert_equal :disconnected, app.status
      assert_match(/Certificate fetch failed/, app.logger.entries.last)
      assert_match(/Connection failed/, app.status_message)
    end
  end

  def test_connect_handles_network_error
    stub_request(:get, /.*\/security\/public-key-certificates/)
      .to_raise(SocketError.new("Network down"))

    with_test_terminal do
      app = create_app
      app.send(:connect)

      assert_equal :disconnected, app.status
      assert_match(/Network down/, app.logger.entries.last)
    end
  end

  def test_fetch_invoices_handles_error
    stub_full_auth_success

    with_test_terminal do
      app = create_app

      # Connect (success)
      stub_invoices_response([]) # Initial fetch
      app.send(:connect)
      assert_equal :connected, app.status

      # Now refresh fails
      base_url = "https://#{@client.host}/v2"
      stub_request(:post, "#{base_url}/invoices/query/metadata")
        .to_return(status: 500, body: '{"error":"server error"}')

      app.send(:fetch_invoices)

      assert_empty app.invoices
      assert_match(/Error fetching invoices/, app.logger.entries.last)
    end
  end

  def test_fetch_invoices_handles_network_error
    stub_full_auth_success

    with_test_terminal do
      app = create_app

      stub_invoices_response([])
      app.send(:connect)

      base_url = "https://#{@client.host}/v2"
      stub_request(:post, "#{base_url}/invoices/query/metadata")
        .to_raise(SocketError.new("Net error"))

      app.send(:fetch_invoices)

      assert_match(/ERROR fetching invoices: Net error/, app.logger.entries.last)
    end
  end

  # Navigation tests
  def test_navigation_selects_next_invoice
    with_test_terminal do
      app = create_app_with_invoices(2)

      inject_key("down")
      process_event(app)

      assert_equal 1, app.current_view.selected_index
    end
  end

  def test_navigation_wraps_around_at_end
    with_test_terminal do
      app = create_app_with_invoices(2)
      app.current_view.instance_variable_set(:@selected_index, 1)

      inject_key("down")
      process_event(app)

      assert_equal 0, app.current_view.selected_index
    end
  end

  def test_navigation_selects_previous_invoice
    with_test_terminal do
      app = create_app_with_invoices(2)
      app.current_view.instance_variable_set(:@selected_index, 1)

      inject_key("up")
      process_event(app)

      assert_equal 0, app.current_view.selected_index
    end
  end

  def test_down_arrow_navigates
    with_test_terminal do
      app = create_app_with_invoices(2)

      inject_key("down")
      process_event(app)

      assert_equal 1, app.current_view.selected_index
    end
  end

  def test_up_arrow_navigates
    with_test_terminal do
      app = create_app_with_invoices(2)
      app.current_view.instance_variable_set(:@selected_index, 1)

      inject_key("up")
      process_event(app)

      assert_equal 0, app.current_view.selected_index
    end
  end

  # Detail view tests
  def test_detail_view_toggling
    with_test_terminal do
      app = create_app_with_invoices(2)

      # Open detail view
      inject_key("enter")
      process_event(app)

      assert_instance_of Ksef::Tui::Views::Detail, app.current_view

      # Close detail view
      inject_key("esc")
      process_event(app)

      assert_instance_of Ksef::Tui::Views::Main, app.current_view
    end
  end

  def test_detail_view_switches_invoices_with_left_right_keys
    with_test_terminal do
      app = create_app_with_invoices(2)

      inject_key("enter")
      process_event(app)
      assert_instance_of Ksef::Tui::Views::Detail, app.current_view
      assert_equal "INV-0", app.current_view.invoice.ksef_number

      inject_key("right")
      process_event(app)
      assert_equal "INV-1", app.current_view.invoice.ksef_number

      inject_key("right")
      process_event(app)
      assert_equal "INV-1", app.current_view.invoice.ksef_number

      inject_key("left")
      process_event(app)
      assert_equal "INV-0", app.current_view.invoice.ksef_number
    end
  end

  def test_detail_view_respects_selected_row_index_when_opened
    with_test_terminal do
      app = create_app_with_invoices(3)
      app.current_view.instance_variable_set(:@selected_index, 1)

      inject_key("enter")
      process_event(app)

      assert_instance_of Ksef::Tui::Views::Detail, app.current_view
      assert_equal "INV-1", app.current_view.invoice.ksef_number

      inject_key("right")
      process_event(app)
      assert_equal "INV-2", app.current_view.invoice.ksef_number

      inject_key("left")
      process_event(app)
      assert_equal "INV-1", app.current_view.invoice.ksef_number
    end
  end

  def test_detail_view_navigation_uses_cached_xml_preview
    xml_1 = <<~XML
      <fa:Faktura xmlns:fa="http://crd.gov.pl/wzor/2025/06/25/13775/">
        <fa:Fa>
          <fa:P_2>XML/CACHED/1</fa:P_2>
        </fa:Fa>
      </fa:Faktura>
    XML

    xml_2 = <<~XML
      <fa:Faktura xmlns:fa="http://crd.gov.pl/wzor/2025/06/25/13775/">
        <fa:Fa>
          <fa:P_2>XML/CACHED/2</fa:P_2>
        </fa:Fa>
      </fa:Faktura>
    XML

    base_url = "https://#{@client.host}/v2"
    stub_request(:get, "#{base_url}/invoices/ksef/KSEF-CACHED-1")
      .with(headers: { "Accept" => "application/xml", "Authorization" => "Bearer access-token" })
      .to_return(status: 200, body: xml_1, headers: { "Content-Type" => "application/xml" })
    stub_request(:get, "#{base_url}/invoices/ksef/KSEF-CACHED-2")
      .with(headers: { "Accept" => "application/xml", "Authorization" => "Bearer access-token" })
      .to_return(status: 200, body: xml_2, headers: { "Content-Type" => "application/xml" })

    with_test_terminal do
      app = create_app
      app.client.access_token = "access-token"
      app.invoices = [
        Ksef::Models::Invoice.new({ "ksefNumber" => "KSEF-CACHED-1", "invoiceNumber" => "META/1" }),
        Ksef::Models::Invoice.new({ "ksefNumber" => "KSEF-CACHED-2", "invoiceNumber" => "META/2" })
      ]

      inject_key("enter")
      process_event(app)
      assert_equal "XML/CACHED/1", app.current_view.invoice.invoice_number

      inject_key("right")
      process_event(app)
      assert_equal "XML/CACHED/2", app.current_view.invoice.invoice_number

      inject_key("left")
      process_event(app)
      assert_equal "XML/CACHED/1", app.current_view.invoice.invoice_number

      assert_requested(:get, "#{base_url}/invoices/ksef/KSEF-CACHED-1", times: 1)
      assert_requested(:get, "#{base_url}/invoices/ksef/KSEF-CACHED-2", times: 1)
    end
  end

  def test_detail_view_uses_xml_preview_data
    stub_full_auth_success
    stub_invoices_response([ {
      "ksefNumber" => "KSEF-XML-1",
      "invoiceNumber" => "META/1",
      "issueDate" => "2026-01-01",
      "grossAmount" => "100.00",
      "currency" => "PLN",
      "seller" => { "name" => "Meta Seller" }
    } ])

    xml = <<~XML
      <fa:Faktura xmlns:fa="http://crd.gov.pl/wzor/2025/06/25/13775/">
        <fa:Podmiot1>
          <fa:DaneIdentyfikacyjne>
            <fa:NIP>1234567890</fa:NIP>
            <fa:Nazwa>XML Seller</fa:Nazwa>
          </fa:DaneIdentyfikacyjne>
          <fa:Adres>
            <fa:Ulica>Sprzedazowa</fa:Ulica>
            <fa:NrDomu>7</fa:NrDomu>
            <fa:KodPocztowy>00-010</fa:KodPocztowy>
            <fa:Miejscowosc>Warszawa</fa:Miejscowosc>
          </fa:Adres>
        </fa:Podmiot1>
        <fa:Podmiot2>
          <fa:DaneIdentyfikacyjne>
            <fa:NIP>9876543210</fa:NIP>
            <fa:Nazwa>XML Buyer</fa:Nazwa>
          </fa:DaneIdentyfikacyjne>
        </fa:Podmiot2>
        <fa:Fa>
          <fa:RodzajFaktury>VAT</fa:RodzajFaktury>
          <fa:KodWaluty>PLN</fa:KodWaluty>
          <fa:P_1>2026-02-11</fa:P_1>
          <fa:P_2>XML/1</fa:P_2>
          <fa:P_18A>2026-02-20</fa:P_18A>
          <fa:P_18B>transfer</fa:P_18B>
          <fa:P_13_1>100.00</fa:P_13_1>
          <fa:P_14_1>23.00</fa:P_14_1>
          <fa:P_15>123.00</fa:P_15>
        </fa:Fa>
        <fa:FaWiersz>
          <fa:NrWierszaFa>1</fa:NrWierszaFa>
          <fa:P_7>Pozycja XML</fa:P_7>
          <fa:P_8A>szt</fa:P_8A>
          <fa:P_8B>1</fa:P_8B>
          <fa:P_9A>100.00</fa:P_9A>
          <fa:P_11>100.00</fa:P_11>
          <fa:P_12>23</fa:P_12>
          <fa:P_11Vat>23.00</fa:P_11Vat>
          <fa:P_11A>123.00</fa:P_11A>
        </fa:FaWiersz>
      </fa:Faktura>
    XML

    base_url = "https://#{@client.host}/v2"
    stub_request(:get, "#{base_url}/invoices/ksef/KSEF-XML-1")
      .with(headers: { "Accept" => "application/xml", "Authorization" => "Bearer access-token" })
      .to_return(status: 200, body: xml, headers: { "Content-Type" => "application/xml" })

    with_test_terminal do
      app = create_app
      app.send(:connect)
      assert_equal :connected, app.status
      assert_equal 1, app.invoices.length

      inject_key("enter")
      process_event(app)

      assert_instance_of Ksef::Tui::Views::Detail, app.current_view
      assert_equal "XML/1", app.current_view.invoice.invoice_number
      assert_equal "XML Seller", app.current_view.invoice.seller_name
      assert_equal "XML Buyer", app.current_view.invoice.buyer_name
      assert_equal "9876543210", app.current_view.invoice.buyer_nip
      assert_equal "VAT", app.current_view.invoice.invoice_type
      assert_equal "2026-02-20", app.current_view.invoice.payment_due_date
      assert_equal "transfer", app.current_view.invoice.payment_method
      assert_equal :xml, app.current_view.invoice.data_source
      assert_equal 1, app.current_view.invoice.items.length
      assert_equal "Pozycja XML", app.current_view.invoice.items.first["description"]
      assert_equal xml, app.current_view.invoice.xml
    end
  end

  # Debug view tests
  def test_debug_view_toggle
    with_test_terminal do
      app = create_app

      # Open debug view
      inject_key("D")
      process_event(app)

      assert_instance_of Ksef::Tui::Views::Debug, app.current_view
    end
  end

  # Quit tests
  def test_quit_with_q_key
    with_test_terminal do
      app = create_app

      inject_key("q")
      result = process_event(app)

      assert_equal :quit, result
    end
  end

  def test_quit_with_ctrl_c
    with_test_terminal do
      app = create_app

      # Ctrl+C should quit
      inject_key(:ctrl_c)
      result = process_event(app)

      assert_equal :quit, result
    end
  end

  # View stack tests
  def test_push_pop_view
    with_test_terminal do
      app = create_app

      assert_equal 1, app.view_stack.size

      debug_view = Ksef::Tui::Views::Debug.new(app)
      app.push_view(debug_view)

      assert_equal 2, app.view_stack.size
      assert_equal debug_view, app.current_view

      app.pop_view

      assert_equal 1, app.view_stack.size
      assert_instance_of Ksef::Tui::Views::Main, app.current_view
    end
  end

  def test_pop_view_maintains_at_least_one_view
    with_test_terminal do
      app = create_app

      app.pop_view
      app.pop_view
      app.pop_view

      assert_equal 1, app.view_stack.size
      refute_nil app.current_view
    end
  end

  def test_select_profile_resets_runtime_state
    with_test_terminal do
      app = create_app
      @config.profiles << Ksef::Models::Profile.new(
        name: "Other",
        nip: "2222222222",
        token: "other-token",
        host: "api.ksef.mf.gov.pl"
      )

      app.invoices = [ Ksef::Models::Invoice.new({ "ksefNumber" => "INV-OLD" }) ]
      app.status = :connected
      app.status_message = "Connected"
      app.instance_variable_set(:@session, Ksef::Session.new(
        access_token: "valid-token",
        access_token_valid_until: (Time.now + 3600).iso8601
      ))
      app.instance_variable_set(:@invoice_preview_cache, { "INV-OLD" => Ksef::Models::Invoice.new({ "ksefNumber" => "INV-OLD" }) })

      app.select_profile("Other")

      assert_equal "Other", app.current_profile.name
      assert_nil app.session
      assert_empty app.invoices
      assert_empty app.instance_variable_get(:@invoice_preview_cache)
      assert_equal :disconnected, app.status
      assert_equal Ksef::I18n.t("app.press_connect"), app.status_message
      assert_instance_of Ksef::Tui::Views::Main, app.current_view
    end
  end

  # Public action methods tests
  def test_connect_bang_connects_synchronously
    stub_full_auth_success
    stub_invoices_response([])

    with_test_terminal do
      app = create_app
      app.connect!

      assert_equal :connected, app.status
    end
  end

  def test_refresh_bang_refreshes_synchronously
    stub_invoices_response([ { "ksefNumber" => "INV-REFRESH" } ])

    with_test_terminal do
      app = create_app
      session = Ksef::Session.new(
        access_token: "valid-token",
        access_token_valid_until: Time.now + 3600
      )
      app.instance_variable_set(:@session, session)
      app.instance_variable_set(:@status, :connected)

      app.refresh!

      assert_equal 1, app.invoices.length
    end
  end

  private

  def build_test_config
    config = Ksef::Config.new(File.join(Dir.tmpdir, "ksef_app_test_#{Process.pid}_#{object_id}.yml"))
    config.locale = :en
    config.max_retries = 0
    config.open_timeout = 10
    config.read_timeout = 15
    config.write_timeout = 10
    config.default_host = "api.ksef.mf.gov.pl"

    profile = Ksef::Models::Profile.new(
      name: "Test",
      nip: "1234567890",
      token: "test-token",
      host: "api.ksef.mf.gov.pl"
    )
    config.profiles = [ profile ]
    config.default_profile_name = profile.name
    config.current_profile_name = profile.name
    config
  end

  def process_event(app)
    event = RatatuiRuby.poll_event
    app.current_view.handle_input(event)
  end

  def create_app_with_invoices(count)
    app = create_app
    app.invoices = count.times.map do |i|
      Ksef::Models::Invoice.new({
        "ksefNumber" => "INV-#{i}",
        "seller" => { "name" => "Seller #{i}" },
        "grossAmount" => (100 * (i + 1)).to_s,
        "currency" => "PLN"
      })
    end
    app
  end

  def stub_auth_failure
    base_url = @client.send(:base_url)
    stub_request(:get, "#{base_url}/security/public-key-certificates")
      .to_return(status: 401, body: { error: "Unauthorized" }.to_json)
  end

  def stub_full_auth_success
    base_url = "https://#{@client.host}/v2"
    cert = self.class.test_certificate

    # 1. Mock certificate endpoint
    stub_request(:get, "#{base_url}/security/public-key-certificates")
      .to_return(
        status: 200,
        body: [ {
          "usage" => [ "KsefTokenEncryption" ],
          "certificate" => Base64.strict_encode64(cert.to_der)
        } ].to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # 2. Mock challenge endpoint
    stub_request(:post, "#{base_url}/auth/challenge")
      .to_return(
        status: 200,
        body: '{"challenge": "test-challenge", "timestamp": "2026-02-09T12:00:00Z", "timestampMs": 1770638400000}',
        headers: { "Content-Type" => "application/json" }
      )

    # 3. Mock auth endpoint
    stub_request(:post, "#{base_url}/auth/ksef-token")
      .to_return(
        status: 200,
        body: {
          authenticationToken: { token: "auth-token" },
          referenceNumber: "ref-123"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # 4. Mock status check endpoint
    stub_request(:get, "#{base_url}/auth/ref-123")
      .to_return(
        status: 200,
        body: '{"status": {"code": 200, "description": "ok"}}',
        headers: { "Content-Type" => "application/json" }
      )

    # 5. Mock token redeem endpoint
    stub_request(:post, "#{base_url}/auth/token/redeem")
      .to_return(
        status: 200,
        body: {
          accessToken: { token: "access-token", validUntil: "2026-12-31T23:59:59Z" },
          refreshToken: { token: "refresh-token" }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_invoices_response(invoices)
    base_url = "https://#{@client.host}/v2"
    stub_request(:post, "#{base_url}/invoices/query/metadata")
      .to_return(
        status: 200,
        body: { "invoices" => invoices }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

end
