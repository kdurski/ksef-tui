# frozen_string_literal: true

require_relative "view_test_helper"

class DebugViewTest < Minitest::Test
  include ViewTestHelper

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
end
