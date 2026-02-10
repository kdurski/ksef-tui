# frozen_string_literal: true

require_relative "view_test_helper"

class DetailViewTest < Minitest::Test
  include ViewTestHelper

  def test_detail_view_render
    invoice = Ksef::Models::Invoice.new({
      "ksefNumber" => "KSEF-123",
      "grossAmount" => "12345",
      "currency" => "EUR",
      "seller" => {"name" => "Seller"},
      "buyer" => {"name" => "Buyer"}
    })

    view = Ksef::Views::Detail.new(@app, invoice)

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
      assert_includes content, "123.45 EUR"
      assert_includes content, "Seller"
      assert_includes content, "Buyer"
    end
  end
end
