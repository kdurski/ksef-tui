# frozen_string_literal: true

require_relative "view_test_helper"

class MainViewTest < ActiveSupport::TestCase
  include ViewTestHelper

  def test_main_view_render
    view = Ksef::Tui::Views::Main.new(@app)

    # Setup state
    @app.status = :connected
    @app.current_profile = Ksef::Models::Profile.new(name: "production", nip: "123", token: "tok")
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

      # Verify Header content includes profile name
      header_content = header.text.map { |l|
        if l.is_a?(String)
          l
        else
          l.spans.map { |s| s.respond_to?(:content) ? s.content : s.to_s }.join
        end
      }.join
      assert_includes header_content, "Connected"
      assert_includes header_content, "PRODUCTION"

      # Verify Table content
      rows = table.rows
      assert_equal 1, rows.length
      assert_equal "KSEF-123", rows[0].cells[0]
      assert_equal "Seller A", rows[0].cells[3]
      assert_equal "100.00 PLN", rows[0].cells[4]
    end
  end

  def test_main_view_input_handling
    view = Ksef::Tui::Views::Main.new(@app)
    @app.invoices = [
      Ksef::Models::Invoice.new({"ksefNumber" => "1"}),
      Ksef::Models::Invoice.new({"ksefNumber" => "2"})
    ]

    # Test navigation
    view.handle_input(RatatuiRuby::Event::Key.new(code: "down"))
    assert_equal 1, view.selected_index

    # Wrap around
    view.handle_input(RatatuiRuby::Event::Key.new(code: "down"))
    assert_equal 0, view.selected_index

    view.handle_input(RatatuiRuby::Event::Key.new(code: "up"))
    assert_equal 1, view.selected_index

    # Test enter (details)
    @app.define_singleton_method(:push_view) { |v| @pushed_view = v }
    view.handle_input(RatatuiRuby::Event::Key.new(code: "enter"))
    assert_kind_of Ksef::Tui::Views::Detail, @app.instance_variable_get(:@pushed_view)

    # Test quit
    assert_equal :quit, view.handle_input(RatatuiRuby::Event::Key.new(code: "q"))

    # Test refresh (only if connected)
    @app.status = :connected
    @app.define_singleton_method(:refresh!) { @refreshed = true }
    view.handle_input(RatatuiRuby::Event::Key.new(code: "r"))
    assert @app.instance_variable_get(:@refreshed)

    # Test connect (only if not loading)
    @app.status = :disconnected
    @app.define_singleton_method(:connect!) { @connected = true }
    view.handle_input(RatatuiRuby::Event::Key.new(code: "c"))
    assert @app.instance_variable_get(:@connected)
  end

  def test_profile_selector_shortcut
    view = Ksef::Tui::Views::Main.new(@app)

    @app.define_singleton_method(:open_profile_selector) { @profile_selector_opened = true }
    view.handle_input(RatatuiRuby::Event::Key.new(code: "p"))
    assert @app.instance_variable_get(:@profile_selector_opened)
  end

  def test_language_toggle_shortcut
    view = Ksef::Tui::Views::Main.new(@app)

    @app.define_singleton_method(:toggle_locale) { @locale_toggled = true }
    view.handle_input(RatatuiRuby::Event::Key.new(code: "L"))
    assert @app.instance_variable_get(:@locale_toggled)
  end

  def test_render_shows_disconnected_status_without_profile
    view = Ksef::Tui::Views::Main.new(@app)
    @app.status = :disconnected
    @app.invoices = []
    @app.status_message = "Press c"

    with_test_terminal do
      frame = mock_frame
      view.render(frame, frame.area)

      header = frame.rendered_widgets[0][:widget]
      placeholder = frame.rendered_widgets[1][:widget]

      header_content = header.text.map { |line|
        line.respond_to?(:spans) ? line.spans.map(&:content).join : line.to_s
      }.join
      assert_includes header_content, "Disconnected"
      assert_includes header_content, "no profile"
      assert_equal "Press c", placeholder.text
    end
  end

  def test_render_shows_connected_empty_message
    view = Ksef::Tui::Views::Main.new(@app)
    @app.status = :connected
    @app.invoices = []
    @app.status_message = "Should not be shown"

    with_test_terminal do
      frame = mock_frame
      view.render(frame, frame.area)

      placeholder = frame.rendered_widgets[1][:widget]
      assert_equal "No invoices found", placeholder.text
    end
  end

  def test_handle_input_unknown_key_returns_nil
    view = Ksef::Tui::Views::Main.new(@app)
    assert_nil view.handle_input(RatatuiRuby::Event::Key.new(code: "x"))
  end

  def test_enter_clamps_selected_index_after_invoices_shrink
    view = Ksef::Tui::Views::Main.new(@app)

    @app.invoices = [
      Ksef::Models::Invoice.new({"ksefNumber" => "1"}),
      Ksef::Models::Invoice.new({"ksefNumber" => "2"})
    ]
    view.handle_input(RatatuiRuby::Event::Key.new(code: "down"))
    assert_equal 1, view.selected_index

    @app.invoices = [Ksef::Models::Invoice.new({"ksefNumber" => "only"})]
    @app.define_singleton_method(:push_view) { |v| @pushed_view = v }

    view.handle_input(RatatuiRuby::Event::Key.new(code: "enter"))

    pushed = @app.instance_variable_get(:@pushed_view)
    assert_kind_of Ksef::Tui::Views::Detail, pushed
    assert_equal "only", pushed.invoice["ksefNumber"]
    assert_equal 0, view.selected_index
  end
end
