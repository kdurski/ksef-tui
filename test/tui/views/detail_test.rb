# frozen_string_literal: true

require_relative "view_test_helper"

class DetailViewTest < Minitest::Test
  include ViewTestHelper

  def test_detail_view_render
    invoice = Ksef::Models::Invoice.new({
      "ksefNumber" => "KSEF-123",
      "grossAmount" => "12345",
      "currency" => "EUR",
      "invoiceType" => "VAT",
      "paymentDueDate" => "2026-03-01",
      "paymentMethod" => "transfer",
      "seller" => {"name" => "Seller", "address" => "Seller St 1"},
      "buyer" => {"name" => "Buyer", "nip" => "9876543210", "address" => "Buyer Ave 2"},
      "items" => [{
        "position" => "1",
        "description" => "Service A",
        "quantity" => "2",
        "unit" => "h",
        "unitPrice" => "2500",
        "netAmount" => "5000",
        "vatRate" => "23",
        "vatAmount" => "1150",
        "grossAmount" => "6150"
      }]
    })

    view = Ksef::Tui::Views::Detail.new(@app, invoice)

    with_test_terminal do
      frame = mock_frame
      view.render(frame, frame.area)

      # Verify Widgets: Detail, Footer
      assert_equal 2, frame.rendered_widgets.length

      detail = frame.rendered_widgets[0][:widget]

      lines = detail.text
      content = lines.map { |l|
        if l.is_a?(String)
          l
        else
          l.spans.map(&:content).join
        end
      }.join("\n")

      assert_includes content, "KSEF-123"
      assert_includes content, "Data Source: JSON fallback (metadata)"
      assert_includes content, "VAT"
      assert_includes content, "123.45 EUR"
      assert_includes content, "Seller"
      assert_includes content, "Buyer"
      assert_includes content, "9876543210"
      assert_includes content, "Seller St 1"
      assert_includes content, "Buyer Ave 2"
      assert_includes content, "2026-03-01"
      assert_includes content, "transfer"
      assert_includes content, "Item: #1 Service A"
      assert_includes content, "Qty: 2"
      assert_includes content, "VAT Rate: 23%"
    end
  end
end
