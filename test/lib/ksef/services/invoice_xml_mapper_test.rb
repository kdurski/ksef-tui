# frozen_string_literal: true

require "test_helper"
class InvoiceXmlMapperTest < ActiveSupport::TestCase
  def setup
    # Defines Ksef::InvoiceError used by mapper.
    Ksef::Models::Invoice
  end

  def test_call_maps_polish_schema_xml
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

    mapper = Ksef::Services::InvoiceXmlMapper.new(ksef_number: "KSEF-123")
    result = mapper.call(xml)

    assert_equal "KSEF-123", result["ksefNumber"]
    assert_equal "FV/9/2026", result["invoiceNumber"]
    assert_equal "VAT", result["invoiceType"]
    assert_equal "2026-02-11", result["issueDate"]
    assert_equal "2026-02-10", result["invoicingDate"]
    assert_equal "150.00", result["netAmount"]
    assert_equal "34.50", result["vatAmount"]
    assert_equal "184.50", result["grossAmount"]
    assert_equal "PLN", result["currency"]
    assert_equal "Seller Sp. z o.o.", result.dig("seller", "name")
    assert_equal "Buyer SA", result.dig("buyer", "name")
    assert_equal "Usluga testowa", result["items"].first["description"]
    assert_equal xml, result["xml"]
  end

  def test_call_raises_on_invalid_xml
    mapper = Ksef::Services::InvoiceXmlMapper.new(ksef_number: "KSEF-123")

    error = assert_raises(Ksef::InvoiceError) { mapper.call("<Invoice>") }
    assert_match(/Invalid invoice XML/, error.message)
  end
end
