# frozen_string_literal: true

require "test_helper"
class BaseViewTest < ActiveSupport::TestCase
  class ConcreteView < Ksef::Tui::Views::Base
    def render(_frame, _area)
      :rendered
    end

    def handle_input(_event)
      :handled
    end
  end

  def test_base_raises_not_implemented_for_render_and_input
    base = Ksef::Tui::Views::Base.new(Object.new)

    assert_raises(NotImplementedError) { base.render(nil, nil) }
    assert_raises(NotImplementedError) { base.handle_input(nil) }
  end

  def test_base_exposes_app_and_helper_accessors
    app = Struct.new(:logger, :session).new(:logger_obj, :session_obj)
    app.instance_variable_set(:@tui, :tui_obj)
    view = ConcreteView.new(app)

    assert_equal app, view.app
    assert_equal :tui_obj, view.send(:tui)
    assert_equal :logger_obj, view.send(:logger)
    assert_equal :session_obj, view.send(:session)
  end
end
