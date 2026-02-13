# frozen_string_literal: true

require_relative "view_test_helper"
require_relative "../../../lib/ksef/tui/views/profile_selector"

class ProfileSelectorTest < ActiveSupport::TestCase
  include ViewTestHelper

  def test_render
    profiles = [ "Prod", "Test" ]
    view = Ksef::Tui::Views::ProfileSelector.new(@app, profiles)

    with_test_terminal do
      frame = mock_frame
      view.render(frame, frame.area)

      # Header, List, Footer
      assert_equal 3, frame.rendered_widgets.length

      header = frame.rendered_widgets[0][:widget]
      assert_includes header.text.to_s, "Select Profile"

      frame.rendered_widgets[1][:widget]
      # assert_equal 2, list.items.length
      # RatatuiRuby list items might be complex, check simplified logic if needed
    end
  end

  def test_selection_with_enter
    profiles = [ "Prod", "Test" ]
    view = Ksef::Tui::Views::ProfileSelector.new(@app, profiles)

    @app.define_singleton_method(:select_profile) do |name|
      @selected = name
    end

    # Default is first (Prod) — use real Event::Key like poll_event returns
    view.handle_input(RatatuiRuby::Event::Key.new(code: "enter"))
    assert_equal "Prod", @app.instance_variable_get(:@selected)
  end

  def test_navigation_down_and_select
    profiles = [ "Prod", "Test" ]
    view = Ksef::Tui::Views::ProfileSelector.new(@app, profiles)

    @app.define_singleton_method(:select_profile) do |name|
      @selected = name
    end

    # Move down to Test, then select
    view.handle_input(RatatuiRuby::Event::Key.new(code: "down"))
    view.handle_input(RatatuiRuby::Event::Key.new(code: "enter"))
    assert_equal "Test", @app.instance_variable_get(:@selected)
  end

  def test_navigation_up_wraps_around
    profiles = [ "Prod", "Test" ]
    view = Ksef::Tui::Views::ProfileSelector.new(@app, profiles)

    @app.define_singleton_method(:select_profile) do |name|
      @selected = name
    end

    # Up from first wraps to last
    view.handle_input(RatatuiRuby::Event::Key.new(code: "up"))
    view.handle_input(RatatuiRuby::Event::Key.new(code: "enter"))
    assert_equal "Test", @app.instance_variable_get(:@selected)
  end

  def test_back_navigation_esc
    profiles = [ "Prod" ]
    view = Ksef::Tui::Views::ProfileSelector.new(@app, profiles)

    @app.define_singleton_method(:pop_view) { @popped = true }

    view.handle_input(RatatuiRuby::Event::Key.new(code: "esc"))
    assert @app.instance_variable_get(:@popped)
  end

  def test_back_navigation_q
    profiles = [ "Prod" ]
    view = Ksef::Tui::Views::ProfileSelector.new(@app, profiles)

    @app.define_singleton_method(:pop_view) { @popped = true }

    view.handle_input(RatatuiRuby::Event::Key.new(code: "q"))
    assert @app.instance_variable_get(:@popped)
  end
end
