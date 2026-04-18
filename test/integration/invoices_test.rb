# frozen_string_literal: true

require "test_helper"

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

  def invoice_xml_api_url(ksef_number)
    "https://api-test.example/v2/invoices/ksef/#{ksef_number}"
  end
end
