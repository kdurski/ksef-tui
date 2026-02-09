# frozen_string_literal: true

module Ksef
  module Tui
    # Keyboard input handling for the TUI
    module InputHandler
      def handle_input
        event = @tui.poll_event

        case event
        in { type: :key, code: 'c', modifiers: ['ctrl'] }
          :quit
        in { type: :key, code: 'q' }
          handle_quit
        in { type: :key, code: 'esc' } | { type: :key, code: 'escape' } | { type: :key, code: 'b' }
          @show_detail = false
          nil
        in { type: :key, code: 'enter' }
          @show_detail = true if @invoices.any?
          nil
        in { type: :key, code: 'down' } | { type: :key, code: 'j' }
          navigate_down
        in { type: :key, code: 'up' } | { type: :key, code: 'k' }
          navigate_up
        in { type: :key, code: 'c' }
          connect unless @status == :loading
          nil
        in { type: :key, code: 'r' }
          refresh if @status == :connected
          nil
        else
          nil
        end
      end

      private

      def handle_quit
        if @show_detail
          @show_detail = false
          nil
        else
          :quit
        end
      end

      def navigate_down
        return unless @invoices.any?
        @selected_index = (@selected_index + 1) % @invoices.length
        nil
      end

      def navigate_up
        return unless @invoices.any?
        @selected_index = (@selected_index - 1) % @invoices.length
        nil
      end
    end
  end
end
