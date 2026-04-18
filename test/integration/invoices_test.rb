# frozen_string_literal: true

require "test_helper"
require "csv"

class InvoicesTest < ActionDispatch::IntegrationTest
  def setup
    super
    @config_path = File.join(Dir.tmpdir, "invoices_test_#{Process.pid}_#{object_id}.yml")
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
    @invoice_xml = <<~XML
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
    @invoice_list = [
      {
        ksefNumber: "KSEF-1",
        invoiceNumber: "FV/1/2026",
        issueDate: "2026-02-11",
        netAmount: "100.00",
        grossAmount: "123.00",
        currency: "PLN",
        invoiceType: "VAT",
        seller: {
          name: "Acme Sp. z o.o.",
          nip: "1234567890"
        }
      },
      {
        ksefNumber: "KSEF-2",
        invoiceNumber: "FV/2/2026",
        issueDate: "2026-02-12",
        netAmount: "200.00",
        grossAmount: "246.00",
        currency: "EUR",
        invoiceType: "VAT",
        seller: {
          name: "Beta S.A.",
          nip: "0987654321"
        }
      }
    ]
  end

  def teardown
    Profile.config_file = nil
    FileUtils.rm_f(@config_path)
    super
  end

  def test_show_renders_xml_and_pdf_download_controls
    authenticate_session!
    stub_invoice_xml_fetch

    get invoice_path("KSEF-XML-1")

    assert_response :success
    assert_select "a", text: "Download XML"
    assert_select "button[data-controller='invoice-pdf-download']", text: "Download PDF"
    assert_select "button[data-invoice-pdf-download-xml-url-value='#{xml_invoice_path("KSEF-XML-1")}']"
    assert_select "button[data-invoice-pdf-download-download-name-value='2026-02-11 - KSEF-XML-1']"
  end

  def test_xml_endpoint_returns_invoice_xml
    authenticate_session!
    stub_invoice_xml_fetch

    get xml_invoice_path("KSEF-XML-1"), headers: { "ACCEPT" => "application/xml" }

    assert_response :success
    assert_equal "application/xml", response.media_type
    assert_equal @invoice_xml, response.body
  end

  def test_xml_endpoint_returns_unauthorized_without_session
    get xml_invoice_path("KSEF-XML-1"), headers: { "ACCEPT" => "application/xml" }

    assert_response :unauthorized
  end

  def test_index_redirects_to_login_when_session_expires_upstream
    authenticate_session!
    stub_request(:post, "https://api-test.example/v2/invoices/query/metadata?pageSize=100")
      .with(headers: { "Authorization" => "Bearer session-token" })
      .to_return(status: 401, body: '{"error":"HTTP 401"}', headers: { "Content-Type" => "application/json" })

    get invoices_path

    assert_redirected_to new_session_path
    follow_redirect!
    assert_response :success
    assert_match(/Session expired\. Please log in again\./, response.body)
  end

  def test_index_redirects_to_login_when_session_expires_with_custom_error_message
    authenticate_session!
    stub_request(:post, "https://api-test.example/v2/invoices/query/metadata?pageSize=100")
      .with(headers: { "Authorization" => "Bearer session-token" })
      .to_return(status: 401, body: '{"error":"token expired"}', headers: { "Content-Type" => "application/json" })

    get invoices_path

    assert_redirected_to new_session_path
    follow_redirect!
    assert_response :success
    assert_match(/Session expired\. Please log in again\./, response.body)
  end

  def test_index_shows_alert_when_upstream_invoice_query_fails
    authenticate_session!
    stub_request(:post, invoice_query_api_url)
      .with(headers: { "Authorization" => "Bearer session-token" })
      .to_return(status: 429, body: '{"error":"rate limit exceeded"}', headers: { "Content-Type" => "application/json" })

    get invoices_path

    assert_response :success
    assert_match(/Failed to fetch invoices: rate limit exceeded/, response.body)
    assert_select "h3", text: "No invoices found"
  end

  def test_index_defaults_to_last_30_days_and_renders_dynamic_preset_labels
    authenticate_session!

    travel_to Time.utc(2026, 4, 18, 10, 0, 0) do
      stub_invoice_list_fetch

      get invoices_path
    end

    assert_response :success
    assert_select "a[href='#{download_csv_invoices_path(format: :csv)}']", text: "Download CSV"
    assert_select "p", text: "Showing invoices from the last 30 days"
    assert_select "label", text: "This month (April 2026)"
    assert_select "label", text: "Last month (March 2026)"
    assert_select "input[type='radio'][value='last_30_days'][checked='checked']"
    assert_invoice_query_requested(from: Date.new(2026, 3, 19), to: Date.new(2026, 4, 18))
  end

  def test_index_uses_last_30_days_preset_when_explicitly_selected
    authenticate_session!

    travel_to Time.utc(2026, 4, 18, 10, 0, 0) do
      stub_invoice_list_fetch

      get invoices_path, params: { range: "last_30_days" }
    end

    assert_response :success
    assert_select "a[href='#{download_csv_invoices_path(format: :csv, range: "last_30_days")}']", text: "Download CSV"
    assert_invoice_query_requested(from: Date.new(2026, 3, 19), to: Date.new(2026, 4, 18))
  end

  def test_index_uses_this_month_preset_and_preserves_it_for_csv
    authenticate_session!

    travel_to Time.utc(2026, 4, 18, 10, 0, 0) do
      stub_invoice_list_fetch

      get invoices_path, params: { range: "this_month" }
    end

    assert_response :success
    assert_select "p", text: "Showing invoices from April 2026 to date"
    assert_select "input[type='radio'][value='this_month'][checked='checked']"
    assert_select "a[href='#{download_csv_invoices_path(format: :csv, range: "this_month")}']", text: "Download CSV"
    assert_invoice_query_requested(from: Date.new(2026, 4, 1), to: Date.new(2026, 4, 18))
  end

  def test_index_uses_last_month_preset_for_the_full_previous_calendar_month
    authenticate_session!

    travel_to Time.utc(2026, 4, 18, 10, 0, 0) do
      stub_invoice_list_fetch

      get invoices_path, params: { range: "last_month" }
    end

    assert_response :success
    assert_select "p", text: "Showing invoices from March 2026"
    assert_select "input[type='radio'][value='last_month'][checked='checked']"
    assert_invoice_query_requested(from: Date.new(2026, 3, 1), to: Date.new(2026, 3, 31))
  end

  def test_index_uses_manual_custom_date_range
    authenticate_session!
    stub_invoice_list_fetch

    get invoices_path, params: {
      range: "custom",
      from_date: "2026-02-01",
      to_date: "2026-02-15"
    }

    assert_response :success
    assert_select "p", text: "Showing invoices from 2026-02-01 to 2026-02-15"
    assert_select "input[type='radio'][value='custom'][checked='checked']"
    assert_select "input#from_date[value='2026-02-01']"
    assert_select "input#to_date[value='2026-02-15']"
    assert_select "a[href='#{download_csv_invoices_path(format: :csv, range: "custom", from_date: "2026-02-01", to_date: "2026-02-15")}']", text: "Download CSV"
    assert_invoice_query_requested(from: Date.new(2026, 2, 1), to: Date.new(2026, 2, 15))
  end

  def test_index_shows_validation_error_and_skips_fetch_for_invalid_manual_dates
    authenticate_session!

    get invoices_path, params: {
      range: "custom",
      from_date: "2026-02-30",
      to_date: "2026-03-02"
    }

    assert_response :success
    assert_select "div", text: /Use valid calendar dates for both From and To\./
    assert_select "input[type='radio'][value='custom'][checked='checked']"
    assert_select "span[aria-disabled='true']", text: "Download CSV"
    assert_select "a", text: "Download CSV", count: 0
    assert_invoice_query_not_made
  end

  def test_index_shows_validation_error_and_skips_fetch_when_from_date_is_after_to_date
    authenticate_session!

    get invoices_path, params: {
      range: "custom",
      from_date: "2026-04-19",
      to_date: "2026-04-18"
    }

    assert_response :success
    assert_select "div", text: /The From date cannot be later than the To date\./
    assert_select "span[aria-disabled='true']", text: "Download CSV"
    assert_invoice_query_not_made
  end

  def test_index_renders_month_labels_across_year_boundaries
    authenticate_session!

    travel_to Time.utc(2026, 1, 10, 10, 0, 0) do
      stub_invoice_list_fetch

      get invoices_path
    end

    assert_response :success
    assert_select "label", text: "This month (January 2026)"
    assert_select "label", text: "Last month (December 2025)"
  end

  def test_index_renders_disabled_download_csv_control_when_no_invoices_are_present
    authenticate_session!
    stub_invoice_list_fetch(invoices: [])

    get invoices_path

    assert_response :success
    assert_select "span[aria-disabled='true']", text: "Download CSV"
    assert_select "a", text: "Download CSV", count: 0
  end

  def test_download_csv_endpoint_returns_invoice_csv_attachment
    authenticate_session!

    travel_to Time.utc(2026, 4, 18, 10, 0, 0) do
      stub_invoice_list_fetch

      get download_csv_invoices_path(format: :csv)
    end

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_equal "utf-8", response.charset
    assert_includes response.headers["Content-Disposition"], "attachment"
    assert_includes response.headers["Content-Disposition"], "invoices-2026-04-18.csv"

    rows = CSV.parse(response.body, headers: true)

    assert_equal [
      "Invoice issue date",
      "Seller name",
      "Net total amount (excluding VAT)",
      "Total amount including VAT",
      "Currency"
    ], rows.headers
    assert_equal 2, rows.length
    assert_equal [ "2026-02-11", "Acme Sp. z o.o.", "100.00", "123.00", "PLN" ], rows[0].fields
    assert_equal [ "2026-02-12", "Beta S.A.", "200.00", "246.00", "EUR" ], rows[1].fields
    assert_invoice_query_requested(from: Date.new(2026, 3, 19), to: Date.new(2026, 4, 18))
  end

  def test_download_csv_endpoint_uses_the_active_filtered_range
    authenticate_session!

    travel_to Time.utc(2026, 4, 18, 10, 0, 0) do
      stub_invoice_list_fetch

      get download_csv_invoices_path(format: :csv, range: "last_month")
    end

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_invoice_query_requested(from: Date.new(2026, 3, 1), to: Date.new(2026, 3, 31))
  end

  def test_download_csv_endpoint_returns_unauthorized_without_session
    get download_csv_invoices_path(format: :csv)

    assert_response :unauthorized
  end

  def test_download_csv_endpoint_redirects_to_login_when_session_expires_upstream
    authenticate_session!
    stub_request(:post, "https://api-test.example/v2/invoices/query/metadata?pageSize=100")
      .with(headers: { "Authorization" => "Bearer session-token" })
      .to_return(status: 401, body: '{"error":"HTTP 401"}', headers: { "Content-Type" => "application/json" })

    get download_csv_invoices_path(format: :csv)

    assert_redirected_to new_session_path
    follow_redirect!
    assert_response :success
    assert_match(/Session expired\. Please log in again\./, response.body)
  end

  def test_download_csv_endpoint_redirects_back_with_alert_when_invoice_query_fails
    authenticate_session!
    stub_request(:post, invoice_query_api_url)
      .with(headers: { "Authorization" => "Bearer session-token" })
      .to_return(status: 429, body: '{"error":"rate limit exceeded"}', headers: { "Content-Type" => "application/json" })

    get download_csv_invoices_path(format: :csv, range: "this_month")

    assert_redirected_to invoices_path(range: "this_month")
    follow_redirect!
    assert_response :success
    assert_match(/Failed to fetch invoices: rate limit exceeded/, response.body)
  end

  def test_xml_endpoint_returns_upstream_error_status
    authenticate_session!
    stub_request(:get, invoice_xml_api_url("KSEF-MISSING"))
      .with(headers: { "Accept" => "application/xml", "Authorization" => "Bearer session-token" })
      .to_return(status: 400, body: '{"error":"invoice missing"}', headers: { "Content-Type" => "application/json" })

    get xml_invoice_path("KSEF-MISSING"), headers: { "ACCEPT" => "application/xml" }

    assert_response :bad_request
    assert_match(/invoice missing/, response.body)
  end

  def test_download_endpoint_still_returns_xml_attachment
    authenticate_session!
    stub_invoice_xml_fetch

    get download_invoice_path("KSEF-XML-1")

    assert_response :success
    assert_equal "application/xml", response.media_type
    assert_includes response.headers["Content-Disposition"], "attachment"
    assert_includes response.headers["Content-Disposition"], "KSEF-XML-1.xml"
    assert_equal @invoice_xml, response.body
  end

  private

  def authenticate_session!
    post sessions_path, params: { profile_id: "hento-testowe" }
    login_request = KsefLoginRequest.last
    login_request.complete_success!(
      access_token: "session-token",
      refresh_token: "refresh-token",
      valid_until: "2026-02-20T10:00:00Z",
      refresh_token_valid_until: "2026-02-21T10:00:00Z"
    )

    get finalize_session_path(login_request)
    assert_redirected_to root_path
  end

  def stub_invoice_xml_fetch(ksef_number = "KSEF-XML-1")
    stub_request(:get, invoice_xml_api_url(ksef_number))
      .with(headers: { "Accept" => "application/xml", "Authorization" => "Bearer session-token" })
      .to_return(status: 200, body: @invoice_xml, headers: { "Content-Type" => "application/xml" })
  end

  def stub_invoice_list_fetch(invoices: @invoice_list)
    stub_request(:post, invoice_query_api_url)
      .with(headers: { "Authorization" => "Bearer session-token" })
      .to_return(
        status: 200,
        body: { invoices: invoices }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def assert_invoice_query_requested(from:, to:)
    assert_requested(:post, invoice_query_api_url, times: 1) do |request|
      body = JSON.parse(request.body)

      assert_equal "PermanentStorage", body.dig("dateRange", "dateType")
      assert_equal from.beginning_of_day.iso8601, body.dig("dateRange", "from")
      assert_equal to.end_of_day.iso8601, body.dig("dateRange", "to")
    end
  end

  def assert_invoice_query_not_made
    assert_not_requested :post, invoice_query_api_url
  end

  def invoice_query_api_url
    "https://api-test.example/v2/invoices/query/metadata?pageSize=100"
  end

  def invoice_xml_api_url(ksef_number)
    "https://api-test.example/v2/invoices/ksef/#{ksef_number}"
  end
end
