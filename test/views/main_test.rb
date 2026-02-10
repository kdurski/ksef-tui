# frozen_string_literal: true

require_relative "view_test_helper"

class MainViewTest < Minitest::Test
  include ViewTestHelper

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

  def test_main_view_input_handling
    view = Ksef::Views::Main.new(@app)
    @app.invoices = [
      Ksef::Models::Invoice.new({"ksefNumber" => "1"}),
      Ksef::Models::Invoice.new({"ksefNumber" => "2"})
    ]

    # Test navigation
    view.handle_input({type: :key, code: "down"})
    assert_equal 1, view.selected_index

    # Wrap around
    view.handle_input({type: :key, code: "down"})
    assert_equal 0, view.selected_index

    view.handle_input({type: :key, code: "up"})
    assert_equal 1, view.selected_index

    # Test enter (details)
    @app.define_singleton_method(:push_view) { |v| @pushed_view = v }
    view.handle_input({type: :key, code: "enter"})
    assert_kind_of Ksef::Views::Detail, @app.instance_variable_get(:@pushed_view)

    # Test quit
    assert_equal :quit, view.handle_input({type: :key, code: "q"})

    # Test refresh (only if connected)
    @app.status = :connected
    @app.define_singleton_method(:trigger_refresh) { @refreshed = true }
    view.handle_input({type: :key, code: "r"})
    assert @app.instance_variable_get(:@refreshed)

    # Test connect (only if not loading)
    @app.status = :disconnected
    @app.define_singleton_method(:trigger_connect) { @connected = true }
    view.handle_input({type: :key, code: "c"})
    assert @app.instance_variable_get(:@connected)
  end
end
