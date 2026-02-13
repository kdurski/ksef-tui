# frozen_string_literal: true

require_relative "view_test_helper"

class DebugViewTest < ActiveSupport::TestCase
  include ViewTestHelper

  def test_debug_view_render
    view = Ksef::Tui::Views::Debug.new(@app)

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
      assert_includes info_text, "[REDACTED]"
      refute_includes info_text, "secret-token"
      assert_includes info_text, "tomorrow"
      assert_includes info_text, "api.ksef.mf.gov.pl"
      assert_includes info_text, "3"
      assert_includes info_text, "10/15/10"
    end
  end

  def test_debug_view_render_with_empty_api_logs
    view = Ksef::Tui::Views::Debug.new(@app)

    with_test_terminal do
      frame = mock_frame
      view.render(frame, frame.area)
      table = frame.rendered_widgets[2][:widget]
      assert_includes table.rows[0].cells[0], "No API calls recorded yet"
    end
  end

  def test_debug_view_handle_input_close
    view = Ksef::Tui::Views::Debug.new(@app)
    @app.define_singleton_method(:pop_view) { @popped = true }

    view.handle_input(RatatuiRuby::Event::Key.new(code: "q"))
    assert @app.instance_variable_get(:@popped)
  end

  def test_debug_view_handle_input_navigation_and_enter
    view = Ksef::Tui::Views::Debug.new(@app)
    @app.logger.api_logs << Ksef::Models::ApiLog.new(
      timestamp: Time.now,
      http_method: "GET",
      path: "/one",
      status: 200,
      duration: 0.1
    )
    @app.logger.api_logs << Ksef::Models::ApiLog.new(
      timestamp: Time.now,
      http_method: "GET",
      path: "/two",
      status: 200,
      duration: 0.1
    )

    view.handle_input(RatatuiRuby::Event::Key.new(code: "down"))
    assert_equal 1, view.instance_variable_get(:@selected_log_index)

    @app.define_singleton_method(:push_view) { |v| @pushed_view = v }
    view.handle_input(RatatuiRuby::Event::Key.new(code: "enter"))
    pushed = @app.instance_variable_get(:@pushed_view)
    assert_kind_of Ksef::Tui::Views::ApiDetail, pushed

    view.handle_input(RatatuiRuby::Event::Key.new(code: "up"))
    assert_equal 0, view.instance_variable_get(:@selected_log_index)
  end
end
