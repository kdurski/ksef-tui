# frozen_string_literal: true

module Ksef
  module Tui
    # Rendering logic for the TUI views
    module Views
      def render(frame)
        if @show_detail && @invoices[@selected_index]
          render_detail_view(frame)
        else
          render_list_view(frame)
        end
      end

      private

      def render_list_view(frame)
        layout = @tui.layout_split(
          frame.area,
          direction: :vertical,
          constraints: [
            @tui.constraint_length(3),   # Header
            @tui.constraint_fill(1),     # Table
            @tui.constraint_length(10),  # Log
            @tui.constraint_length(3)    # Footer
          ]
        )

        render_header(frame, layout[0])
        render_table(frame, layout[1])
        render_log(frame, layout[2])
        render_footer(frame, layout[3])
      end

      def render_log(frame, area)
        log_text = @log_entries.join("\n")
        log_widget = @tui.paragraph(
          text: log_text,
          block: @tui.block(
            title: 'Activity Log',
            borders: [:all],
            border_style: { fg: 'dark_gray' }
          )
        )
        frame.render_widget(log_widget, area)
      end

      def render_header(frame, area)
        status_span = case @status
                      when :connected
                        @tui.text_span(content: '● Connected', style: @status_connected)
                      when :loading
                        @tui.text_span(content: '◐ Loading...', style: @status_loading)
                      else
                        @tui.text_span(content: '○ Disconnected', style: @status_disconnected)
                      end

        header = @tui.paragraph(
          text: [
            @tui.text_line(spans: [
              @tui.text_span(content: 'KSeF Invoice Viewer', style: @title_style),
              @tui.text_span(content: '  '),
              status_span
            ])
          ],
          alignment: :left,
          block: @tui.block(borders: [:all], border_style: { fg: 'cyan' })
        )

        frame.render_widget(header, area)
      end

      def render_table(frame, area)
        if @invoices.empty?
          empty_msg = @status == :connected ? 'No invoices found' : @status_message
          placeholder = @tui.paragraph(
            text: empty_msg,
            alignment: :center,
            block: @tui.block(title: 'Invoices', borders: [:all])
          )
          frame.render_widget(placeholder, area)
          return
        end

        rows = @invoices.map do |inv|
          @tui.table_row(cells: [
            inv['ksefNumber'] || '',
            truncate(inv['invoiceNumber'] || '', 15),
            inv['issueDate'] || '',
            inv.dig('seller', 'name') || '',
            format_amount(inv['grossAmount'], inv['currency'])
          ])
        end

        table = @tui.table(
          header: ['KSeF Number', 'Invoice #', 'Date', 'Seller', 'Amount'],
          rows: rows,
          widths: [
            @tui.constraint_length(40),
            @tui.constraint_length(17),
            @tui.constraint_length(12),
            @tui.constraint_fill(1),
            @tui.constraint_length(15)
          ],
          selected_row: @selected_index,
          row_highlight_style: @highlight_style,
          highlight_symbol: '▶ ',
          block: @tui.block(
            title: "Invoices (#{@invoices.length})",
            borders: [:all]
          )
        )

        frame.render_widget(table, area)
      end

      def render_footer(frame, area)
        controls = @tui.paragraph(
          text: [
            @tui.text_line(spans: [
              @tui.text_span(content: '↑/↓', style: @hotkey_style),
              @tui.text_span(content: ': Navigate  '),
              @tui.text_span(content: 'Enter', style: @hotkey_style),
              @tui.text_span(content: ': Details  '),
              @tui.text_span(content: 'c', style: @hotkey_style),
              @tui.text_span(content: ': Connect  '),
              @tui.text_span(content: 'r', style: @hotkey_style),
              @tui.text_span(content: ': Refresh  '),
              @tui.text_span(content: 'q', style: @hotkey_style),
              @tui.text_span(content: ': Quit')
            ])
          ],
          alignment: :center,
          block: @tui.block(borders: [:all])
        )

        frame.render_widget(controls, area)
      end

      def render_detail_view(frame)
        inv = @invoices[@selected_index]

        layout = @tui.layout_split(
          frame.area,
          direction: :vertical,
          constraints: [
            @tui.constraint_fill(1),
            @tui.constraint_length(3)
          ]
        )

        lines = build_detail_lines(inv)

        detail = @tui.paragraph(
          text: lines,
          block: @tui.block(
            title: 'Invoice Details',
            titles: [{ content: 'Esc: Back', position: :bottom, alignment: :right }],
            borders: [:all],
            border_style: { fg: 'cyan' }
          )
        )

        footer = @tui.paragraph(
          text: [
            @tui.text_line(spans: [
              @tui.text_span(content: 'b/Esc/q', style: @hotkey_style),
              @tui.text_span(content: ': Back to list  '),
              @tui.text_span(content: 'Ctrl+C', style: @hotkey_style),
              @tui.text_span(content: ': Quit')
            ])
          ],
          alignment: :center,
          block: @tui.block(borders: [:all])
        )

        frame.render_widget(detail, layout[0])
        frame.render_widget(footer, layout[1])
      end

      def build_detail_lines(inv)
        [
          detail_line('KSeF Number', inv['ksefNumber']),
          detail_line('Invoice Number', inv['invoiceNumber']),
          '',
          detail_line('Issue Date', inv['issueDate']),
          detail_line('Invoicing Date', inv['invoicingDate']),
          '',
          section_header('Seller'),
          detail_line('Name', inv.dig('seller', 'name')),
          detail_line('NIP', inv.dig('seller', 'nip')),
          '',
          section_header('Buyer'),
          detail_line('Name', inv.dig('buyer', 'name')),
          '',
          section_header('Amounts'),
          amount_line('Net', inv['netAmount'], inv['currency']),
          amount_line('VAT', inv['vatAmount'], inv['currency'], highlight: false),
          amount_line('Gross', inv['grossAmount'], inv['currency'])
        ]
      end

      def detail_line(label, value)
        @tui.text_line(spans: [
          @tui.text_span(content: "#{label}: ", style: @hotkey_style),
          @tui.text_span(content: value || 'N/A')
        ])
      end

      def section_header(title)
        @tui.text_line(spans: [
          @tui.text_span(content: "── #{title} ──", style: @title_style)
        ])
      end

      def amount_line(label, amount, currency, highlight: true)
        style = highlight ? @amount_style : nil
        @tui.text_line(spans: [
          @tui.text_span(content: "#{label}: ", style: @hotkey_style),
          @tui.text_span(content: format_amount(amount, currency), style: style)
        ])
      end
    end
  end
end
