# frozen_string_literal: true

require "ratatui_ruby"

module Ksef
  # Style definitions for the TUI
  module Styles
    TITLE = RatatuiRuby::Style::Style.new(fg: :cyan, modifiers: [:bold])
    STATUS_CONNECTED = RatatuiRuby::Style::Style.new(fg: :green, modifiers: [:bold])
    STATUS_DISCONNECTED = RatatuiRuby::Style::Style.new(fg: :red)
    STATUS_LOADING = RatatuiRuby::Style::Style.new(fg: :yellow)
    HIGHLIGHT = RatatuiRuby::Style::Style.new(fg: :black, bg: :cyan)
    HOTKEY = RatatuiRuby::Style::Style.new(modifiers: [:bold, :underlined])
    ERROR = RatatuiRuby::Style::Style.new(fg: :red, modifiers: [:bold])
    AMOUNT = RatatuiRuby::Style::Style.new(fg: :green)
    DEBUG_BORDER = RatatuiRuby::Style::Style.new(fg: :magenta)
  end
end
