# frozen_string_literal: true

require_relative "view_test_helper"

class ApiDetailViewTest < Minitest::Test
  include ViewTestHelper

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
