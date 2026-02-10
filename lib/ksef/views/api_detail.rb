# frozen_string_literal: true

require_relative "base"

module Ksef
  module Views
    class ApiDetail < Base
      def initialize(app, api_log)
        super(app)
        @api_log = api_log
        @scroll_offset = 0
      end

      def render(frame, area)
        layout = tui.layout_split(
          area,
          direction: :vertical,
          constraints: [
            tui.constraint_fill(1),
            tui.constraint_length(3)
          ]
        )

        # Build detail content
        lines = build_content_lines

        # Apply scrolling
        visible_lines = lines[@scroll_offset..] || []

        text_content = visible_lines.join("\n")

        detail = RatatuiRuby::Widgets::Paragraph.new(
          text: text_content,
          block: tui.block(
            title: "API Log Details",
            borders: [:all],
            border_style: Styles::DEBUG_BORDER
          )
        )

        frame.render_widget(detail, layout[0])

        footer = tui.paragraph(
          text: [
            tui.text_line(spans: [
              tui.text_span(content: "↑/↓", style: Styles::HOTKEY),
              tui.text_span(content: ": Scroll  "),
              tui.text_span(content: "Esc", style: Styles::HOTKEY),
              tui.text_span(content: ": Back")
            ])
          ],
          alignment: :center,
          block: tui.block(borders: [:all])
        )
        frame.render_widget(footer, layout[1])
      end

      def handle_input(event)
        # Recalculate content lines to determine max scroll
        lines = build_content_lines
        max_scroll = [lines.length - 1, 0].max

        case event
        in {type: :key, code: "esc"} | {type: :key, code: "escape"} | {type: :key, code: "q"}
          @app.pop_view
        in {type: :key, code: "down"} | {type: :key, code: "j"} | {type: :mouse, kind: "scroll_down"}
          @scroll_offset = [@scroll_offset + 1, max_scroll].min
        in {type: :key, code: "up"} | {type: :key, code: "k"} | {type: :mouse, kind: "scroll_up"}
          @scroll_offset = [@scroll_offset - 1, 0].max
        else
          nil
        end
      end

      private

      def build_content_lines
        lines = []
        lines << "Method: #{@api_log.method}"
        lines << "Path:   #{@api_log.path}"
        lines << "Status: #{@api_log.status}"
        lines << "Time:   #{@api_log.timestamp.strftime("%H:%M:%S.%L")}"
        lines << "Duration: #{(@api_log.duration * 1000).round(2)}ms"
        lines << "Error: #{@api_log.error.class}: #{@api_log.error.message}" if @api_log.error
        lines << ""
        lines << "--- Request Headers ---"
        @api_log.request_headers&.each { |k, v| lines << "#{k}: #{v}" }
        lines << ""
        lines << "--- Request Body ---"
        lines << sanitize_body(@api_log.request_body)
        lines << ""
        lines << "--- Response Headers ---"
        @api_log.response_headers&.each { |k, v| lines << "#{k}: #{v}" }
        lines << ""
        lines << "--- Response Body ---"
        lines << sanitize_body(@api_log.response_body)
        lines
      end

      def sanitize_body(content)
        return "(empty)" if content.nil? || content.empty?

        content = content.to_s

        # Try to pretty print JSON
        begin
          parsed = JSON.parse(content)
          return JSON.pretty_generate(parsed)
        rescue JSON::ParserError
          # Not JSON, proceed
        end

        # Force encoding to UTF-8
        content = content.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")

        if content.length > 2000
          "#{content[0..2000]}... (truncated, #{content.length} bytes)"
        else
          content
        end
      end
    end
  end
end
