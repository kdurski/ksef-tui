# frozen_string_literal: true

require_relative 'base'

module Ksef
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
        in { type: :key, code: 'c', modifiers: ['ctrl'] } | { type: :key, code: 'q' }
          :quit
        in { type: :key, code: 'D' } | { type: :key, code: 'd', modifiers: ['shift'] }
          @app.push_view(Ksef::Views::Debug.new(@app))
        in { type: :key, code: 'enter' }
          if @app.invoices.any?
            invoice = @app.invoices[@selected_index]
            @app.push_view(Ksef::Views::Detail.new(@app, invoice))
          end
        in { type: :key, code: 'down' } | { type: :key, code: 'j' }
          navigate_down
        in { type: :key, code: 'up' } | { type: :key, code: 'k' }
          navigate_up
        in { type: :key, code: 'c' }
          @app.trigger_connect unless @app.status == :loading
        in { type: :key, code: 'r' }
          @app.trigger_refresh if @app.status == :connected
        else
          nil
        end
      end

      private

      def render_header(frame, area)
        # Access styles via app instance public accessors
        title_style = @app.title_style
        
        status_span = case @app.status
                      when :connected
                        tui.text_span(content: '● Connected', style: @app.status_connected)
                      when :loading
                        tui.text_span(content: '◐ Loading...', style: @app.status_loading)
                      else
                        tui.text_span(content: '○ Disconnected', style: @app.status_disconnected)
                      end

        header = tui.paragraph(
          text: [
            tui.text_line(spans: [
              tui.text_span(content: 'KSeF Invoice Viewer', style: title_style),
              tui.text_span(content: '  '),
              status_span
            ])
          ],
          alignment: :left,
          block: tui.block(borders: [:all], border_style: { fg: 'cyan' })
        )

        frame.render_widget(header, area)
      end

      def render_table(frame, area)
        if @app.invoices.empty?
          empty_msg = @app.status == :connected ? 'No invoices found' : @app.status_message
          placeholder = tui.paragraph(
            text: empty_msg,
            alignment: :center,
            block: tui.block(title: 'Invoices', borders: [:all])
          )
          frame.render_widget(placeholder, area)
          return
        end
        
        # Ensure helper methods are available
        # Base class doesn't include Helpers, so we invoke via App or duplicate?
        # App includes Helpers.
        
        rows = @app.invoices.map do |inv|
          tui.table_row(cells: [
            inv['ksefNumber'] || '',
            @app.truncate(inv['invoiceNumber'] || '', 15),
            inv['issueDate'] || '',
            inv.seller_name || '', # Using Invoice model method
            @app.format_amount(inv['grossAmount'], inv['currency'])
          ])
        end

        table = tui.table(
          header: ['KSeF Number', 'Invoice #', 'Date', 'Seller', 'Amount'],
          rows: rows,
          widths: [
            tui.constraint_length(40),
            tui.constraint_length(17),
            tui.constraint_length(12),
            tui.constraint_fill(1),
            tui.constraint_length(15)
          ],
          selected_row: @selected_index,
          row_highlight_style: @app.highlight_style,
          highlight_symbol: '▶ ',
          block: tui.block(
            title: "Invoices (#{@app.invoices.length})",
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
            title: 'Activity Log',
            borders: [:all],
            border_style: { fg: 'dark_gray' }
          )
        )
        frame.render_widget(log_widget, area)
      end

      def render_footer(frame, area)
        hotkey_style = @app.hotkey_style
        
        controls = tui.paragraph(
          text: [
            tui.text_line(spans: [
              tui.text_span(content: '↑/↓', style: hotkey_style),
              tui.text_span(content: ': Navigate  '),
              tui.text_span(content: 'Enter', style: hotkey_style),
              tui.text_span(content: ': Details  '),
              tui.text_span(content: 'c', style: hotkey_style),
              tui.text_span(content: ': Connect  '),
              tui.text_span(content: 'r', style: hotkey_style),
              tui.text_span(content: ': Refresh  '),
              tui.text_span(content: 'D', style: hotkey_style),
              tui.text_span(content: ': Debug  '),
              tui.text_span(content: 'q', style: hotkey_style),
              tui.text_span(content: ': Quit')
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
    end
  end
end
