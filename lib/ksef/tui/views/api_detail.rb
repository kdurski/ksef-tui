# frozen_string_literal: true

require_relative "base"
require "json"
require "rexml/document"
require "rexml/formatters/pretty"

module Ksef
  module Tui
    module Views
      class ApiDetail < Base
        def initialize(app, api_log_index)
          super(app)
          @api_log_index = api_log_index
          @api_log = app.logger.api_logs[@api_log_index]
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

          api_logs = @app.logger.api_logs
          # Ensure index is within bounds (in case logs were cleared?)
          if api_logs.empty?
            @app.pop_view
            return
          end
          @api_log_index = @api_log_index.clamp(0, api_logs.length - 1)
          @api_log = api_logs[@api_log_index]

          # Build detail content
          lines = build_content_lines

          # Apply scrolling
          visible_lines = lines[@scroll_offset..] || []

          text_content = visible_lines.join("\n")

          title = "#{Ksef::I18n.t("views.api_detail.title")} (#{@api_log_index + 1}/#{api_logs.length})"
          detail = RatatuiRuby::Widgets::Paragraph.new(
            text: text_content,
            block: tui.block(
              title: title,
              borders: [ :all ],
              border_style: Styles::DEBUG_BORDER
            )
          )

          frame.render_widget(detail, layout[0])

          footer = tui.paragraph(
            text: [
              tui.text_line(spans: [
                tui.text_span(content: "←/→", style: Styles::HOTKEY),
                tui.text_span(content: ": #{Ksef::I18n.t("views.main.navigate")}  "),
                tui.text_span(content: "↑/↓", style: Styles::HOTKEY),
                tui.text_span(content: ": #{Ksef::I18n.t("views.api_detail.scroll")}  "),
                tui.text_span(content: "Esc", style: Styles::HOTKEY),
                tui.text_span(content: ": #{Ksef::I18n.t("views.api_detail.back")}")
              ])
            ],
            alignment: :center,
            block: tui.block(borders: [ :all ])
          )
          frame.render_widget(footer, layout[1])
        end

        def handle_input(event)
          # Recalculate content lines to determine max scroll
          lines = build_content_lines
          max_scroll = [ lines.length - 1, 0 ].max
          api_logs = @app.logger.api_logs

          case event
          in { type: :key, code: "esc" } | { type: :key, code: "escape" } | { type: :key, code: "q" }
            @app.pop_view
          in { type: :key, code: "down" } | { type: :mouse, kind: "scroll_down" }
            @scroll_offset = [ @scroll_offset + 1, max_scroll ].min
          in { type: :key, code: "up" } | { type: :mouse, kind: "scroll_up" }
            @scroll_offset = [ @scroll_offset - 1, 0 ].max
          in { type: :key, code: "left" }
            if @api_log_index > 0
              @api_log_index -= 1
              @scroll_offset = 0
              @api_log = api_logs[@api_log_index]
            end
          in { type: :key, code: "right" }
            if @api_log_index < api_logs.length - 1
              @api_log_index += 1
              @scroll_offset = 0
              @api_log = api_logs[@api_log_index]
            end
          else
            nil
          end
        end

        private

        def build_content_lines
          lines = []
          lines << "#{Ksef::I18n.t("views.api_detail.method")}: #{@api_log.http_method}"
          lines << "#{Ksef::I18n.t("views.api_detail.path")}:   #{@api_log.path}"
          lines << "#{Ksef::I18n.t("views.api_detail.status")}: #{@api_log.status}"
          lines << "#{Ksef::I18n.t("views.api_detail.time")}:   #{@api_log.timestamp.strftime("%H:%M:%S.%L")}"
          lines << "#{Ksef::I18n.t("views.api_detail.duration")}: #{(@api_log.duration * 1000).round(2)}ms"
          lines << "#{Ksef::I18n.t("views.api_detail.error")}: #{@api_log.error.class}: #{@api_log.error.message}" if @api_log.error
          lines << ""
          lines << Ksef::I18n.t("views.api_detail.request_headers")
          @api_log.request_headers&.each { |k, v| lines << "#{k}: #{v}" }
          lines << ""
          lines << Ksef::I18n.t("views.api_detail.request_body")
          lines << format_body(@api_log.request_body)
          lines << ""
          lines << Ksef::I18n.t("views.api_detail.response_headers")
          @api_log.response_headers&.each { |k, v| lines << "#{k}: #{v}" }
          lines << ""
          lines << Ksef::I18n.t("views.api_detail.response_body")
          lines << format_body(@api_log.response_body)
          lines
        end

        def format_body(content)
          return Ksef::I18n.t("views.api_detail.empty") if content.nil? || content.empty?

          content = content.to_s

          formatted = format_json(content) || format_xml(content) || content

          # Force encoding to UTF-8
          formatted = formatted.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")

          if formatted.length > 4000
            "#{formatted[0..4000]}#{Ksef::I18n.t("views.api_detail.truncated", bytes: formatted.length)}"
          else
            formatted
          end
        end

        def format_json(content)
          parsed = JSON.parse(content)
          JSON.pretty_generate(parsed)
        rescue JSON::ParserError
          nil
        end

        def format_xml(content)
          return nil unless content.lstrip.start_with?("<")

          document = REXML::Document.new(content)
          formatter = REXML::Formatters::Pretty.new(2)
          formatter.compact = true

          output = +""
          formatter.write(document, output)
          output.strip
        rescue REXML::ParseException
          nil
        end
      end
    end
  end
end
