# frozen_string_literal: true

require "application_system_test_case"

class InvoicesPdfDownloadTest < ApplicationSystemTestCase
  def setup
    super
    @config_path = File.join(Dir.tmpdir, "invoices_pdf_download_test_#{Process.pid}_#{object_id}.yml")
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
    KsefLoginRequest.delete_all
    super
  end

  def test_pdf_generator_bundle_loads_only_after_download_click
    stub_invoice_xml_fetch
    login_and_finalize_session!
    visit invoice_path("KSEF-XML-1")

    assert_text "Invoice Details"
    refute pdf_bundle_requested?, "expected the PDF bundle to stay unloaded before clicking the button"

    page.execute_script(<<~JS)
      window.alert = function(message) {
        window.__lastAlert = message
      }

      HTMLAnchorElement.prototype.click = function() {
        window.__lastDownloadName = this.download
      }
    JS

    click_button "Download PDF"

    assert_selector "button[disabled]", text: "Generating PDF..."
    assert_selector "button:not([disabled])", text: "Download PDF", wait: 20
    assert pdf_bundle_requested?, "expected the PDF bundle to load after clicking the button"
  end

  private

  def login_and_finalize_session!
    visit new_session_path
    click_on "HENTO (testowe)"
    assert_text "Authorizing with KSeF"

    login_request = KsefLoginRequest.find(current_url[%r{/sessions/(\d+)}, 1])
    login_request.complete_success!(
      access_token: "session-token",
      refresh_token: "refresh-token",
      valid_until: "2026-02-20T10:00:00Z",
      refresh_token_valid_until: "2026-02-21T10:00:00Z"
    )

    assert_text "Logged in successfully to KSeF", wait: 10
  end

  def pdf_bundle_requested?
    page.evaluate_script(<<~JS)
      performance.getEntriesByType("resource").some((entry) => entry.name.includes("ksef_pdf_generator"))
    JS
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
