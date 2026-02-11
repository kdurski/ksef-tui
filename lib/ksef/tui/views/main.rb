# frozen_string_literal: true

require_relative "base"

module Ksef
  module Tui
    module Views
      class Main < Base
        attr_reader :selected_index

        def initialize(app)
          super
          @selected_index = 0
        end

        def render(frame, area)
          layout = tui.layout_split(
            area,
            direction: :vertical,
            constraints: [
              tui.constraint_length(3),   # Header
              tui.constraint_fill(1),     # Table
              tui.constraint_length(10),  # Log
              tui.constraint_length(3)    # Footer
            ]
          )

          render_header(frame, layout[0])
          render_table(frame, layout[1])
          render_log(frame, layout[2])
          render_footer(frame, layout[3])
        end

        def handle_input(event)
          case event
          in {type: :key, code: "c", modifiers: ["ctrl"]} | {type: :key, code: "q"}
            :quit
          in {type: :key, code: "D"} | {type: :key, code: "d", modifiers: ["shift"]}
            @app.push_view(Ksef::Tui::Views::Debug.new(@app))
          in {type: :key, code: "p"}
            @app.open_profile_selector
          in {type: :key, code: "L"} | {type: :key, code: "l", modifiers: ["shift"]}
            @app.toggle_locale
          in {type: :key, code: "enter"}
            invoice = selected_invoice
            preview_invoice = @app.preview_invoice(invoice)
            @app.push_view(Ksef::Tui::Views::Detail.new(@app, preview_invoice)) if preview_invoice
          in {type: :key, code: "down"}
            navigate_down
          in {type: :key, code: "up"}
            navigate_up
          in {type: :key, code: "c"}
            @app.connect! unless @app.status == :loading
          in {type: :key, code: "r"}
            @app.refresh! if @app.status == :connected
          else
            nil
          end
        end

        private

        def render_header(frame, area)
          title_style = Styles::TITLE

          status_span = case @app.status
          when :connected
            tui.text_span(content: Ksef::I18n.t("views.main.status.connected"), style: Styles::STATUS_CONNECTED)
          when :loading
            tui.text_span(content: Ksef::I18n.t("views.main.status.loading"), style: Styles::STATUS_LOADING)
          else
            tui.text_span(content: Ksef::I18n.t("views.main.status.disconnected"), style: Styles::STATUS_DISCONNECTED)
          end

          profile_span = if @app.current_profile
            tui.text_span(content: " 「#{@app.current_profile.name.upcase}」", style: {fg: :magenta})
          else
            tui.text_span(content: " 「#{Ksef::I18n.t("views.main.no_profile")}」", style: {fg: :dark_gray})
          end

          header = tui.paragraph(
            text: [
              tui.text_line(spans: [
                tui.text_span(content: Ksef::I18n.t("views.main.title"), style: title_style),
                profile_span,
                tui.text_span(content: " #{Ksef::I18n.t("views.main.invoices_count", count: @app.invoices.length)}", style: Styles::TITLE),
                tui.text_span(content: "  "),
                status_span
              ])
            ],
            alignment: :left,
            block: tui.block(borders: [:all], border_style: {fg: "cyan"})
          )

          frame.render_widget(header, area)
        end

        def render_table(frame, area)
          if @app.invoices.empty?
            empty_msg = (@app.status == :connected) ? Ksef::I18n.t("views.main.no_invoices") : @app.status_message
            placeholder = tui.paragraph(
              text: empty_msg,
              alignment: :center,
              block: tui.block(title: Ksef::I18n.t("views.main.invoices"), borders: [:all])
            )
            frame.render_widget(placeholder, area)
            return
          end

          normalize_selected_index!

          rows = @app.invoices.map do |inv|
            tui.table_row(cells: [
              inv["ksefNumber"] || "",
              @app.truncate(inv["invoiceNumber"] || "", 15),
              inv["issueDate"] || "",
              inv.seller_name || "",
              @app.format_amount(inv["grossAmount"], inv["currency"])
            ])
          end

          table = tui.table(
            header: [
              Ksef::I18n.t("views.main.headers.ksef_number"),
              Ksef::I18n.t("views.main.headers.invoice_number"),
              Ksef::I18n.t("views.main.headers.date"),
              Ksef::I18n.t("views.main.headers.seller"),
              Ksef::I18n.t("views.main.headers.amount")
            ],
            rows: rows,
            widths: [
              tui.constraint_length(40),
              tui.constraint_length(17),
              tui.constraint_length(12),
              tui.constraint_fill(1),
              tui.constraint_length(15)
            ],
            selected_row: @selected_index,
            row_highlight_style: Styles::HIGHLIGHT,
            highlight_symbol: "▶ ",
            block: tui.block(
              title: Ksef::I18n.t("views.main.invoices_count", count: @app.invoices.length),
              borders: [:all]
            )
          )

          frame.render_widget(table, area)
        end

        def render_log(frame, area)
          log_text = @app.logger.entries.join("\n")
          log_widget = tui.paragraph(
            text: log_text,
            block: tui.block(
              title: Ksef::I18n.t("views.main.activity_log"),
              borders: [:all],
              border_style: {fg: "dark_gray"}
            )
          )
          frame.render_widget(log_widget, area)
        end

        def render_footer(frame, area)
          hotkey_style = Styles::HOTKEY

          controls = tui.paragraph(
            text: [
              tui.text_line(spans: [
                tui.text_span(content: "↑/↓", style: hotkey_style),
                tui.text_span(content: ": #{Ksef::I18n.t("views.main.navigate")}  "),
                tui.text_span(content: "Enter", style: hotkey_style),
                tui.text_span(content: ": #{Ksef::I18n.t("views.main.details")}  "),
                tui.text_span(content: " c ", style: Styles::HOTKEY),
                tui.text_span(content: "#{Ksef::I18n.t("views.main.connect")}  "),
                tui.text_span(content: " r ", style: Styles::HOTKEY),
                tui.text_span(content: "#{Ksef::I18n.t("views.main.refresh")}  "),
                tui.text_span(content: " p ", style: Styles::HOTKEY),
                tui.text_span(content: "#{Ksef::I18n.t("views.main.profile")}  "),
                tui.text_span(content: " L ", style: Styles::HOTKEY),
                tui.text_span(content: "#{Ksef::I18n.t("views.main.language")}  "),
                tui.text_span(content: " q ", style: Styles::HOTKEY),
                tui.text_span(content: ": #{Ksef::I18n.t("views.main.quit")}")
              ])
            ],
            alignment: :center,
            block: tui.block(borders: [:all])
          )

          frame.render_widget(controls, area)
        end

        def navigate_down
          return unless @app.invoices.any?
          @selected_index = (@selected_index + 1) % @app.invoices.length
        end

        def navigate_up
          return unless @app.invoices.any?
          @selected_index = (@selected_index - 1) % @app.invoices.length
        end

        def selected_invoice
          return nil unless @app.invoices.any?
          normalize_selected_index!
          @app.invoices[@selected_index]
        end

        def normalize_selected_index!
          return @selected_index = 0 unless @app.invoices.any?
          @selected_index = @selected_index.clamp(0, @app.invoices.length - 1)
        end
      end
    end
  end
end
