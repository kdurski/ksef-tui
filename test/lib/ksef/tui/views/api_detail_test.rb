# frozen_string_literal: true

require_relative "view_test_helper"

class ApiDetailViewTest < ActiveSupport::TestCase
  include ViewTestHelper

  def setup
    super
    # Mock log
    @log1 = Ksef::Models::ApiLog.new(
      timestamp: Time.now,
      http_method: "GET",
      path: "/test/1",
      status: 200,
      duration: 0.1,
      response_body: "Line 1\nLine 2\nLine 3\nLine 4\nLine 5"
    )
    @log2 = Ksef::Models::ApiLog.new(
      timestamp: Time.now,
      http_method: "POST",
      path: "/test/2",
      status: 201,
      duration: 0.2,
      response_body: "Second log"
    )

    # Inject logs into app logger
    @app.logger.api_logs << @log1
    @app.logger.api_logs << @log2
  end

  def test_api_detail_mouse_scroll
    view = Ksef::Tui::Views::ApiDetail.new(@app, 0)

    # Scroll down
    view.handle_input(RatatuiRuby::Event::Mouse.new(kind: "scroll_down", x: 0, y: 0, button: "none"))
    assert_equal 1, view.instance_variable_get(:@scroll_offset)

    # Scroll up
    view.handle_input(RatatuiRuby::Event::Mouse.new(kind: "scroll_up", x: 0, y: 0, button: "none"))
    assert_equal 0, view.instance_variable_get(:@scroll_offset)
  end

  def test_navigation_right
    view = Ksef::Tui::Views::ApiDetail.new(@app, 0)

    # Verify initial state
    view.render(mock_frame, StubRect.new) # Trigger log fetch
    assert_equal @log1, view.instance_variable_get(:@api_log)

    # Navigate right -> log 2
    view.handle_input(RatatuiRuby::Event::Key.new(code: "right"))
    assert_equal 1, view.instance_variable_get(:@api_log_index)
    assert_equal @log2, view.instance_variable_get(:@api_log)

    # Navigate right again (should stay at last)
    view.handle_input(RatatuiRuby::Event::Key.new(code: "right"))
    assert_equal 1, view.instance_variable_get(:@api_log_index)
  end

  def test_navigation_left
    view = Ksef::Tui::Views::ApiDetail.new(@app, 1)

    # Verify initial state
    view.render(mock_frame, StubRect.new) # Trigger log fetch
    assert_equal @log2, view.instance_variable_get(:@api_log)

    # Navigate left -> log 1
    view.handle_input(RatatuiRuby::Event::Key.new(code: "left"))
    assert_equal 0, view.instance_variable_get(:@api_log_index)
    assert_equal @log1, view.instance_variable_get(:@api_log)

    # Navigate left again (should stay at first)
    view.handle_input(RatatuiRuby::Event::Key.new(code: "left"))
    assert_equal 0, view.instance_variable_get(:@api_log_index)
  end

  def test_pop_view_on_empty_logs
    # clear logs
    @app.logger.api_logs.clear

    view = Ksef::Tui::Views::ApiDetail.new(@app, 0)

    # Mock app pop_view
    pop_called = false
    @app.define_singleton_method(:pop_view) { pop_called = true }

    view.render(mock_frame, StubRect.new)
    assert pop_called
  end

  def test_format_body_pretty_prints_xml
    view = Ksef::Tui::Views::ApiDetail.new(@app, 0)
    xml = "<root><child>value</child><nested><x>1</x></nested></root>"

    formatted = view.send(:format_body, xml)

    assert_includes formatted, "<root>"
    assert_includes formatted, "  <child>value</child>"
    assert_includes formatted, "  <nested>"
    assert_includes formatted, "    <x>1</x>"
  end
end
