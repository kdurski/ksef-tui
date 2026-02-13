# frozen_string_literal: true

require "test_helper"
class StylesTest < ActiveSupport::TestCase
  STYLE_CONSTANTS = %i[
    TITLE
    STATUS_CONNECTED
    STATUS_DISCONNECTED
    STATUS_LOADING
    HIGHLIGHT
    HOTKEY
    ERROR
    AMOUNT
    DEBUG_BORDER
  ].freeze

  def test_all_style_constants_are_defined
    STYLE_CONSTANTS.each do |constant_name|
      assert Ksef::Tui::Styles.const_defined?(constant_name), "#{constant_name} is not defined"
      assert_instance_of RatatuiRuby::Style::Style, Ksef::Tui::Styles.const_get(constant_name)
    end
  end
end
