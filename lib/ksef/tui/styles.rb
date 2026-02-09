# frozen_string_literal: true

module Ksef
  module Tui
    # Style definitions for the TUI
    module Styles
      def setup_styles
        @title_style = @tui.style(fg: :cyan, modifiers: [:bold])
        @status_connected = @tui.style(fg: :green, modifiers: [:bold])
        @status_disconnected = @tui.style(fg: :red)
        @status_loading = @tui.style(fg: :yellow)
        @highlight_style = @tui.style(fg: :black, bg: :cyan)
        @hotkey_style = @tui.style(modifiers: [:bold, :underlined])
        @error_style = @tui.style(fg: :red, modifiers: [:bold])
        @amount_style = @tui.style(fg: :green)
      end
    end
  end
end
