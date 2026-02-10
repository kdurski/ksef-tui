# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/ksef/views/main"
require_relative "../lib/ksef/views/detail"
require_relative "../lib/ksef/views/debug"
# require_relative '../lib/ksef/models/invoice' # Already required via app.rb or test_helper

class ViewsTest < Minitest::Test
  include RatatuiRuby::TestHelper

  # Mock App to provide context for Views
  class MockApp
    attr_reader :logger
    attr_accessor :invoices, :status, :status_message, :session

    def initialize
      @invoices = []
      @status = :disconnected
      @status_message = "msg"
      @logger = Ksef::Logger.new
      # Ensure api_logs is available on logger
      unless @logger.respond_to?(:api_logs)
        def @logger.api_logs
          []
        end
      end
      @session = nil
      @tui = RatatuiRuby::TUI.new
    end

    def truncate(str, len)
      (str.length > len) ? str[0...len - 3] + "..." : str
    end

    def format_amount(amount, currency)
      sprintf("%.2f %s", amount.to_f / 100, currency)
    end

    def push_view(view)
    end

    def pop_view
    end

    def trigger_connect
    end

    def trigger_refresh
    end
  end

  def setup
    @app = MockApp.new
  end

  def mock_frame
    frame_double = Struct.new(:area, :rendered_widgets).new(
      StubRect.new(width: 80, height: 24),
      []
    )
    def frame_double.render_widget(widget, area)
      rendered_widgets << {widget: widget, area: area}
    end
    frame_double
  end

  def test_main_view_render
    view = Ksef::Views::Main.new(@app)

    # Setup state
    @app.status = :connected
    @app.invoices = [
      Ksef::Models::Invoice.new({
        "ksefNumber" => "KSEF-123",
        "invoiceNumber" => "INV/001",
        "grossAmount" => "10000",
        "currency" => "PLN",
        "seller" => {"name" => "Seller A"}
      })
    ]

    with_test_terminal do
      frame = mock_frame
      # No need to stub area on frame_double as it has it
      view.render(frame, frame.area)

      # Verify Widgets
      # Header, Table, Log, Footer
      assert_equal 4, frame.rendered_widgets.length

      header = frame.rendered_widgets[0][:widget]
      table = frame.rendered_widgets[1][:widget]

      # Verify Header content
      header_content = header.text.map { |l|
        if l.is_a?(String)
          l
        else
          l.spans.map { |s| s.respond_to?(:content) ? s.content : s.to_s }.join
        end
      }.join
      assert_includes header_content, "Connected"

      # Verify Table content
      rows = table.rows
      assert_equal 1, rows.length
      assert_equal "KSEF-123", rows[0].cells[0]
      assert_equal "Seller A", rows[0].cells[3]
      assert_equal "100.00 PLN", rows[0].cells[4]
    end
  end

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

  def test_debug_view_render
    view = Ksef::Views::Debug.new(@app)

    # Mock session
    @app.session = Ksef::Session.new(
      access_token: "secret-token",
      access_token_valid_until: "tomorrow"
    )

    with_test_terminal do
      frame = mock_frame
      view.render(frame, frame.area)

      # Verify Widgets: Title, Info, API Logs, App Log, Footer
      assert_equal 5, frame.rendered_widgets.length

      title = frame.rendered_widgets[0][:widget]
      info = frame.rendered_widgets[1][:widget]

      assert_equal "DEBUG VIEW", title.text

      info_text = info.text
      assert_includes info_text, "secret-to..."
      assert_includes info_text, "tomorrow"
    end
  end

  def test_api_detail_mouse_scroll
    # Mock log
    log = Ksef::Models::ApiLog.new(
      timestamp: Time.now,
      method: "GET",
      path: "/test",
      status: 200,
      duration: 0.1,
      response_body: "Line 1\nLine 2\nLine 3\nLine 4\nLine 5"
    )

    view = Ksef::Views::ApiDetail.new(@app, log)

    # Scroll down
    view.handle_input({type: :mouse, kind: "scroll_down"})
    assert_equal 1, view.instance_variable_get(:@scroll_offset)

    # Scroll up
    view.handle_input({type: :mouse, kind: "scroll_up"})
    assert_equal 0, view.instance_variable_get(:@scroll_offset)
  end
end
