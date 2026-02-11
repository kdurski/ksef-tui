# frozen_string_literal: true

require_relative "base"

module Ksef
  module Views
    class Debug < Base
      def initialize(app)
        super
        @selected_log_index = 0
      end

      def render(frame, area)
        layout = tui.layout_split(
          area,
          direction: :vertical,
          constraints: [
            tui.constraint_length(3),  # Title
            tui.constraint_length(10), # Session/Config info
            tui.constraint_fill(1),    # API Logs
            tui.constraint_length(10), # App Logs
            tui.constraint_length(3)   # Footer
          ]
        )

        # Title
        title = tui.paragraph(
          text: Ksef::I18n.t("views.debug.title"),
          alignment: :center,
          block: tui.block(borders: [:all], border_style: Styles::DEBUG_BORDER)
        )
        frame.render_widget(title, layout[0])

        # Info
        na = Ksef::I18n.t("views.detail.na")
        config = @app.config
        active_host = @app.client&.host || @app.current_profile&.host || config.default_host
        info_text = [
          "#{Ksef::I18n.t("views.debug.session_active")}: #{session&.active? || false}",
          "#{Ksef::I18n.t("views.debug.token_valid_until")}: #{session&.access_token_valid_until || na}",
          "#{Ksef::I18n.t("views.debug.access_token")}: #{session&.access_token ? (session.access_token[0..8] + "...") : na}",
          "#{Ksef::I18n.t("views.debug.refresh_token")}: #{session&.refresh_token ? (session.refresh_token[0..8] + "...") : na}",
          "#{Ksef::I18n.t("views.debug.refresh_valid_until")}: #{session&.refresh_token_valid_until || na}",
          "",
          "#{Ksef::I18n.t("views.debug.ksef_host")}: #{active_host}",
          "#{Ksef::I18n.t("views.debug.retries")}: #{config.max_retries}",
          "#{Ksef::I18n.t("views.debug.timeouts")}: #{config.open_timeout}/#{config.read_timeout}/#{config.write_timeout}"
        ].join("\n")

        info = tui.paragraph(
          text: info_text,
          block: tui.block(title: Ksef::I18n.t("views.debug.system_info"), borders: [:all])
        )
        frame.render_widget(info, layout[1])

        # API Logs Table
        api_logs = @app.logger.api_logs

        rows = if api_logs.any?
          api_logs.map do |log|
            style = log.success? ? Styles::AMOUNT : Styles::ERROR
            tui.table_row(cells: [
              log.timestamp.strftime("%H:%M:%S"),
              log.http_method,
              log.path,
              log.status.to_s,
              "#{(log.duration * 1000).round}ms"
            ], style: style)
          end
        else
          [tui.table_row(cells: [Ksef::I18n.t("views.debug.no_api_calls")])]
        end

        table = tui.table(
          header: [
            Ksef::I18n.t("views.debug.headers.time"),
            Ksef::I18n.t("views.debug.headers.method"),
            Ksef::I18n.t("views.debug.headers.path"),
            Ksef::I18n.t("views.debug.headers.status"),
            Ksef::I18n.t("views.debug.headers.duration")
          ],
          rows: rows,
          widths: [
            tui.constraint_length(10),
            tui.constraint_length(8),
            tui.constraint_fill(1),
            tui.constraint_length(8),
            tui.constraint_length(10)
          ],
          block: tui.block(title: Ksef::I18n.t("views.debug.api_calls"), borders: [:all]),
          selected_row: @selected_log_index,
          row_highlight_style: Styles::HIGHLIGHT
        )
        frame.render_widget(table, layout[2])

        # App Logs
        log_text = logger.entries.join("\n")
        logs = tui.paragraph(
          text: log_text,
          block: tui.block(title: Ksef::I18n.t("views.debug.app_log"), borders: [:all])
        )
        frame.render_widget(logs, layout[3])

        # Footer
        footer = tui.paragraph(
          text: [
            tui.text_line(spans: [
              tui.text_span(content: "↑/↓", style: Styles::HOTKEY),
              tui.text_span(content: ": #{Ksef::I18n.t("views.debug.select_log")}  "),
              tui.text_span(content: "Enter", style: Styles::HOTKEY),
              tui.text_span(content: ": #{Ksef::I18n.t("views.main.details")}  "),
              tui.text_span(content: "Esc", style: Styles::HOTKEY),
              tui.text_span(content: ": #{Ksef::I18n.t("views.debug.close")}")
            ])
          ],
          alignment: :center,
          block: tui.block(borders: [:all])
        )
        frame.render_widget(footer, layout[4])
      end

      def handle_input(event)
        api_logs = @app.logger.api_logs

        case event
        in {type: :key, code: "D"} | {type: :key, code: "d", modifiers: ["shift"]} | {type: :key, code: "esc"} | {type: :key, code: "escape"} | {type: :key, code: "q"}
          @app.pop_view
        in {type: :key, code: "up"} | {type: :mouse, kind: "scroll_up"}
          @selected_log_index = (@selected_log_index - 1) % [1, api_logs.length].max if api_logs.any?
        in {type: :key, code: "down"} | {type: :mouse, kind: "scroll_down"}
          @selected_log_index = (@selected_log_index + 1) % [1, api_logs.length].max if api_logs.any?
        in {type: :key, code: "enter"}
          if api_logs.any?
            @app.push_view(Ksef::Views::ApiDetail.new(@app, @selected_log_index))
          end
        else
          nil
        end
      end
    end
  end
end
