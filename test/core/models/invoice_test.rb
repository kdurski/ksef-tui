# frozen_string_literal: true

require_relative "../../test_helper"

class TitleTest < ActiveSupport::TestCase
  def test_invoice_initialization
    data = {
      "ksefNumber" => "123",
      "invoiceNumber" => "INV/1",
      "issueDate" => "2023-01-01",
      "invoiceType" => "VAT",
      "paymentDueDate" => "2023-01-10",
      "paymentMethod" => "transfer",
      "seller" => {"name" => "Seller Inc", "nip" => "111", "address" => "Seller St 1"},
      "buyer" => {"name" => "Buyer LLC", "nip" => "222", "address" => "Buyer Ave 2"},
      "items" => [{"description" => "Service", "quantity" => "1"}],
      "grossAmount" => "123.00",
      "currency" => "PLN"
    }

    invoice = Ksef::Models::Invoice.new(data)

    assert_equal "123", invoice.ksef_number
    assert_equal "INV/1", invoice.invoice_number
    assert_equal "2023-01-01", invoice.issue_date
    assert_equal "VAT", invoice.invoice_type
    assert_equal "2023-01-10", invoice.payment_due_date
    assert_equal "transfer", invoice.payment_method
    assert_equal "Seller Inc", invoice.seller_name
    assert_equal "111", invoice.seller_nip
    assert_equal "Seller St 1", invoice.seller_address
    assert_equal "Buyer LLC", invoice.buyer_name
    assert_equal "222", invoice.buyer_nip
    assert_equal "Buyer Ave 2", invoice.buyer_address
    assert_equal :json_fallback, invoice.data_source
    assert_equal 1, invoice.items.length
    assert_equal "123.00", invoice.gross_amount
    assert_equal "PLN", invoice.currency
    assert_equal "123", invoice["ksefNumber"]
  end

  def test_invoice_nil_safety
    invoice = Ksef::Models::Invoice.new(nil)

    assert_nil invoice.ksef_number
    assert_nil invoice.seller_name
    assert_nil invoice.gross_amount
    assert_equal :json_fallback, invoice.data_source
    assert_empty invoice.items
    assert_nil invoice["ksefNumber"]
  end

  def test_find_all_returns_invoice_models
    client = Ksef::Client.new(host: "api.ksef.mf.gov.pl")
    client.access_token = "token-123"

    stub_request(:post, "https://api.ksef.mf.gov.pl/v2/invoices/query/metadata")
      .with(headers: {"Authorization" => "Bearer token-123"})
      .to_return(
        status: 200,
        body: {
          invoices: [
            {"ksefNumber" => "KSEF-1", "invoiceNumber" => "FV/1/2026"},
            {"ksefNumber" => "KSEF-2", "invoiceNumber" => "FV/2/2026"}
          ]
        }.to_json,
        headers: {"Content-Type" => "application/json"}
      )

    invoices = Ksef::Models::Invoice.find_all(
      client: client,
      query_body: {subjectType: "Subject2"}
    )

    assert_equal 2, invoices.length
    assert_instance_of Ksef::Models::Invoice, invoices.first
    assert_equal "KSEF-1", invoices.first.ksef_number
  end

  def test_find_loads_invoice_from_xml_endpoint
    client = Ksef::Client.new(host: "api.ksef.mf.gov.pl")
    client.access_token = "token-123"
    xml = <<~XML
      <fa:Faktura xmlns:fa="http://crd.gov.pl/wzor/2025/06/25/13775/">
        <fa:Podmiot1>
          <fa:DaneIdentyfikacyjne>
            <fa:NIP>1234567890</fa:NIP>
            <fa:Nazwa>Seller Sp. z o.o.</fa:Nazwa>
          </fa:DaneIdentyfikacyjne>
          <fa:Adres>
            <fa:KodKraju>PL</fa:KodKraju>
            <fa:Ulica>Sprzedazowa</fa:Ulica>
            <fa:NrDomu>3</fa:NrDomu>
            <fa:KodPocztowy>00-001</fa:KodPocztowy>
            <fa:Miejscowosc>Warszawa</fa:Miejscowosc>
          </fa:Adres>
        </fa:Podmiot1>
        <fa:Podmiot2>
          <fa:DaneIdentyfikacyjne>
            <fa:NIP>9876543210</fa:NIP>
            <fa:Nazwa>Buyer SA</fa:Nazwa>
          </fa:DaneIdentyfikacyjne>
          <fa:Adres>
            <fa:KodKraju>PL</fa:KodKraju>
            <fa:Ulica>Kupiecka</fa:Ulica>
            <fa:NrDomu>8</fa:NrDomu>
            <fa:KodPocztowy>00-002</fa:KodPocztowy>
            <fa:Miejscowosc>Warszawa</fa:Miejscowosc>
          </fa:Adres>
        </fa:Podmiot2>
        <fa:Fa>
          <fa:RodzajFaktury>VAT</fa:RodzajFaktury>
          <fa:KodWaluty>PLN</fa:KodWaluty>
          <fa:P_1>2026-02-11</fa:P_1>
          <fa:P_2>FV/9/2026</fa:P_2>
          <fa:P_6>2026-02-10</fa:P_6>
          <fa:P_18A>2026-02-25</fa:P_18A>
          <fa:P_18B>transfer</fa:P_18B>
          <fa:P_13_1>100.00</fa:P_13_1>
          <fa:P_13_2>50.00</fa:P_13_2>
          <fa:P_14_1>23.00</fa:P_14_1>
          <fa:P_14_2>11.50</fa:P_14_2>
          <fa:P_15>184.50</fa:P_15>
        </fa:Fa>
        <fa:FaWiersz>
          <fa:NrWierszaFa>1</fa:NrWierszaFa>
          <fa:P_7>Usluga testowa</fa:P_7>
          <fa:P_8A>szt</fa:P_8A>
          <fa:P_8B>2</fa:P_8B>
          <fa:P_9A>50.00</fa:P_9A>
          <fa:P_11>100.00</fa:P_11>
          <fa:P_12>23</fa:P_12>
          <fa:P_11Vat>23.00</fa:P_11Vat>
          <fa:P_11A>123.00</fa:P_11A>
        </fa:FaWiersz>
      </fa:Faktura>
    XML

    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/invoices/ksef/KSEF-123")
      .with(headers: {"Accept" => "application/xml", "Authorization" => "Bearer token-123"})
      .to_return(status: 200, body: xml, headers: {"Content-Type" => "application/xml"})

    invoice = Ksef::Models::Invoice.find(
      client: client,
      ksef_number: "KSEF-123"
    )

    assert_instance_of Ksef::Models::Invoice, invoice
    assert_equal "KSEF-123", invoice.ksef_number
    assert_equal "FV/9/2026", invoice.invoice_number
    assert_equal "2026-02-11", invoice.issue_date
    assert_equal "2026-02-10", invoice.invoicing_date
    assert_equal "VAT", invoice.invoice_type
    assert_equal "2026-02-25", invoice.payment_due_date
    assert_equal "transfer", invoice.payment_method
    assert_equal "Seller Sp. z o.o.", invoice.seller_name
    assert_equal "1234567890", invoice.seller_nip
    assert_match(/Sprzedazowa 3/, invoice.seller_address)
    assert_equal "Buyer SA", invoice.buyer_name
    assert_equal "9876543210", invoice.buyer_nip
    assert_match(/Kupiecka 8/, invoice.buyer_address)
    assert_equal :xml, invoice.data_source
    assert_equal 1, invoice.items.length
    assert_equal "Usluga testowa", invoice.items.first["description"]
    assert_equal "2", invoice.items.first["quantity"]
    assert_equal "23", invoice.items.first["vatRate"]
    assert_equal "150.00", invoice.net_amount
    assert_equal "184.50", invoice.gross_amount
    assert_equal "34.50", invoice.vat_amount
    assert_equal "PLN", invoice.currency
    refute_nil invoice.xml
  end

  def test_find_uses_current_client_when_not_provided
    client = Ksef::Client.new(host: "api.ksef.mf.gov.pl", access_token: "token-xyz")
    Ksef.current_client = client

    stub_request(:get, "https://api.ksef.mf.gov.pl/v2/invoices/ksef/KSEF-ABC")
      .with(headers: {"Accept" => "application/xml", "Authorization" => "Bearer token-xyz"})
      .to_return(
        status: 200,
        body: '<fa:Faktura xmlns:fa="http://crd.gov.pl/wzor/2025/06/25/13775/"><fa:Fa><fa:P_2>FV/ABC</fa:P_2></fa:Fa></fa:Faktura>',
        headers: {"Content-Type" => "application/xml"}
      )

    invoice = Ksef::Models::Invoice.find(ksef_number: "KSEF-ABC")
    assert_equal "FV/ABC", invoice.invoice_number
  ensure
    Ksef.current_client = nil
  end
end
