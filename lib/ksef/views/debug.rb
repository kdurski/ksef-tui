# frozen_string_literal: true

require_relative 'base'

module Ksef
  module Views
    class Debug < Base
      def render(frame, area)
        # Debug view is an overlay, but RatatuiRuby's constraints work on valid areas.
        # If we want it to look like a modal, we can use Clear widget or just render normally.
        # Here we render full screen as per split layout.

        layout = tui.layout_split(
          area,
          direction: :vertical,
          constraints: [
            tui.constraint_length(3),  # Title
            tui.constraint_length(10), # Session/Config info
            tui.constraint_fill(1),    # Full Log
            tui.constraint_length(3)   # Footer
          ]
        )

        # Title
        title = tui.paragraph(
          text: 'DEBUG VIEW',
          alignment: :center,
          block: tui.block(borders: [:all], border_style: Styles::DEBUG_BORDER)
        )
        frame.render_widget(title, layout[0])

        # Info
        info_text = [
          "Session Active: #{session&.active? || false}",
          "Token Valid Until: #{session&.valid_until || 'N/A'}",
          "Access Token: #{session&.token ? (session.token[0..8] + '...') : 'N/A'}",
          "",
          "KSeF Host: #{ENV.fetch('KSEF_HOST', 'api.ksef.mf.gov.pl')}",
          "Open Timeout: #{ENV.fetch('KSEF_OPEN_TIMEOUT', 10)}s",
          "Read Timeout: #{ENV.fetch('KSEF_READ_TIMEOUT', 15)}s",
          "Write Timeout: #{ENV.fetch('KSEF_WRITE_TIMEOUT', 10)}s"
        ].join("\n")

        info = tui.paragraph(
          text: info_text,
          block: tui.block(title: 'System Info', borders: [:all])
        )
        frame.render_widget(info, layout[1])

        # Logs
        log_text = logger.entries.join("\n")
        logs = tui.paragraph(
          text: log_text,
          block: tui.block(title: 'Full Log Buffer', borders: [:all])
        )
        frame.render_widget(logs, layout[2])
        
        # Footer
        footer = tui.paragraph(
          text: 'Press "D" or "Esc" to close debug view',
          alignment: :center,
          block: tui.block(borders: [:all])
        )
        frame.render_widget(footer, layout[3])
      end

      def handle_input(event)
        case event
        in { type: :key, code: 'D' } | { type: :key, code: 'd', modifiers: ['shift'] } | { type: :key, code: 'esc' } | { type: :key, code: 'escape' }
          @app.pop_view
        else
          nil
        end
      end
    end
  end
end
