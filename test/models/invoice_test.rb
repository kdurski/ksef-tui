# frozen_string_literal: true

require_relative "../test_helper"

class TitleTest < Minitest::Test
  def test_invoice_initialization
    data = {
      "ksefNumber" => "123",
      "invoiceNumber" => "INV/1",
      "issueDate" => "2023-01-01",
      "seller" => {"name" => "Seller Inc", "nip" => "111"},
      "buyer" => {"name" => "Buyer LLC"},
      "grossAmount" => "123.00",
      "currency" => "PLN"
    }

    invoice = Ksef::Models::Invoice.new(data)

    assert_equal "123", invoice.ksef_number
    assert_equal "INV/1", invoice.invoice_number
    assert_equal "2023-01-01", invoice.issue_date
    assert_equal "Seller Inc", invoice.seller_name
    assert_equal "111", invoice.seller_nip
    assert_equal "Buyer LLC", invoice.buyer_name
    assert_equal "123.00", invoice.gross_amount
    assert_equal "PLN", invoice.currency
    assert_equal "123", invoice["ksefNumber"]
  end

  def test_invoice_nil_safety
    invoice = Ksef::Models::Invoice.new(nil)

    assert_nil invoice.ksef_number
    assert_nil invoice.seller_name
    assert_nil invoice.gross_amount
    assert_nil invoice["ksefNumber"]
  end
end
