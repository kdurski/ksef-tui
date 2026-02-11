# frozen_string_literal: true

require_relative "base"

module Ksef
  module Tui
    module Views
      class Detail < Base
        MAX_ITEMS_IN_PREVIEW = 8

        attr_reader :invoice

        def initialize(app, invoice)
          super(app)
          @invoice = invoice
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

          lines = build_detail_lines

          detail = tui.paragraph(
            text: lines,
            block: tui.block(
              title: Ksef::I18n.t("views.detail.title"),
              titles: [{content: Ksef::I18n.t("views.detail.back"), position: :bottom, alignment: :right}],
              borders: [:all],
              border_style: {fg: "cyan"}
            )
          )

          hotkey_style = Styles::HOTKEY
          footer = tui.paragraph(
            text: [
              tui.text_line(spans: [
                tui.text_span(content: "b/Esc/q", style: hotkey_style),
                tui.text_span(content: ": #{Ksef::I18n.t("views.detail.back_to_list")}  "),
                tui.text_span(content: "Ctrl+C", style: hotkey_style),
                tui.text_span(content: ": #{Ksef::I18n.t("views.detail.quit")}")
              ])
            ],
            alignment: :center,
            block: tui.block(borders: [:all])
          )

          frame.render_widget(detail, layout[0])
          frame.render_widget(footer, layout[1])
        end

        def handle_input(event)
          case event
          in {type: :key, code: "c", modifiers: ["ctrl"]}
            :quit
          in {type: :key, code: "esc"} | {type: :key, code: "escape"} | {type: :key, code: "b"} | {type: :key, code: "q"}
            @app.pop_view
          else
            nil
          end
        end

        private

        def build_detail_lines
          lines = [
            detail_line(Ksef::I18n.t("views.detail.ksef_number"), @invoice["ksefNumber"]),
            detail_line(Ksef::I18n.t("views.detail.invoice_number"), @invoice["invoiceNumber"]),
            detail_line(Ksef::I18n.t("views.detail.data_source"), data_source_label),
            optional_detail_line(Ksef::I18n.t("views.detail.invoice_type"), @invoice.invoice_type),
            "",
            detail_line(Ksef::I18n.t("views.detail.issue_date"), @invoice["issueDate"]),
            detail_line(Ksef::I18n.t("views.detail.invoicing_date"), @invoice["invoicingDate"]),
            "",
            section_header(Ksef::I18n.t("views.detail.seller")),
            detail_line(Ksef::I18n.t("views.detail.name"), @invoice.seller_name),
            detail_line(Ksef::I18n.t("views.detail.nip"), @invoice.seller_nip),
            optional_detail_line(Ksef::I18n.t("views.detail.address"), @invoice.seller_address),
            "",
            section_header(Ksef::I18n.t("views.detail.buyer")),
            detail_line(Ksef::I18n.t("views.detail.name"), @invoice.buyer_name),
            optional_detail_line(Ksef::I18n.t("views.detail.nip"), @invoice.buyer_nip),
            optional_detail_line(Ksef::I18n.t("views.detail.address"), @invoice.buyer_address),
            "",
            section_header(Ksef::I18n.t("views.detail.amounts")),
            amount_line(Ksef::I18n.t("views.detail.net"), @invoice["netAmount"], @invoice["currency"]),
            amount_line(Ksef::I18n.t("views.detail.vat"), @invoice["vatAmount"], @invoice["currency"], highlight: false),
            amount_line(Ksef::I18n.t("views.detail.gross"), @invoice["grossAmount"], @invoice["currency"])
          ]

          if @invoice.payment_due_date || @invoice.payment_method
            lines << ""
            lines << section_header(Ksef::I18n.t("views.detail.payment"))
            lines << optional_detail_line(Ksef::I18n.t("views.detail.payment_due_date"), @invoice.payment_due_date)
            lines << optional_detail_line(Ksef::I18n.t("views.detail.payment_method"), @invoice.payment_method)
          end

          append_items_section(lines)

          lines.compact
        end

        def detail_line(label, value)
          hotkey_style = Styles::HOTKEY
          tui.text_line(spans: [
            tui.text_span(content: "#{label}: ", style: hotkey_style),
            tui.text_span(content: value || Ksef::I18n.t("views.detail.na"))
          ])
        end

        def section_header(title)
          title_style = Styles::TITLE
          tui.text_line(spans: [
            tui.text_span(content: "── #{title} ──", style: title_style)
          ])
        end

        def amount_line(label, amount, currency, highlight: true)
          hotkey_style = Styles::HOTKEY
          amount_style = Styles::AMOUNT

          style = highlight ? amount_style : nil
          tui.text_line(spans: [
            tui.text_span(content: "#{label}: ", style: hotkey_style),
            tui.text_span(content: @app.format_amount(amount, currency), style: style)
          ])
        end

        def optional_detail_line(label, value)
          return nil if value.nil? || value.to_s.strip.empty?

          detail_line(label, value)
        end

        def data_source_label
          key = @invoice.xml_loaded? ? "views.detail.source_xml" : "views.detail.source_json_fallback"
          Ksef::I18n.t(key)
        end

        def append_items_section(lines)
          items = @invoice.items
          return if items.empty?

          lines << ""
          lines << section_header(Ksef::I18n.t("views.detail.items"))

          items.first(MAX_ITEMS_IN_PREVIEW).each_with_index do |item, index|
            lines.concat(item_lines(item, index + 1))
          end

          hidden_count = items.length - MAX_ITEMS_IN_PREVIEW
          return unless hidden_count.positive?

          lines << detail_line(Ksef::I18n.t("views.detail.more_items"), Ksef::I18n.t("views.detail.more_items_count", count: hidden_count))
        end

        def item_lines(item, fallback_position)
          lines = []
          position = item["position"] || fallback_position
          description = item["description"] || Ksef::I18n.t("views.detail.na")
          lines << detail_line(Ksef::I18n.t("views.detail.item"), "##{position} #{description}")

          attrs = []
          attrs << inline_pair(Ksef::I18n.t("views.detail.quantity"), item["quantity"])
          attrs << inline_pair(Ksef::I18n.t("views.detail.unit"), item["unit"])
          attrs << inline_pair(Ksef::I18n.t("views.detail.unit_price"), format_item_amount(item["unitPrice"]))
          attrs << inline_pair(Ksef::I18n.t("views.detail.vat_rate"), format_vat_rate(item["vatRate"]))
          lines << inline_line(attrs) if attrs.any?

          amounts = []
          amounts << inline_pair(Ksef::I18n.t("views.detail.net"), format_item_amount(item["netAmount"]))
          amounts << inline_pair(Ksef::I18n.t("views.detail.vat"), format_item_amount(item["vatAmount"]))
          amounts << inline_pair(Ksef::I18n.t("views.detail.gross"), format_item_amount(item["grossAmount"]))
          lines << inline_line(amounts) if amounts.any?

          lines << ""
        end

        def inline_pair(label, value)
          return nil if value.nil? || value.to_s.strip.empty?

          "#{label}: #{value}"
        end

        def inline_line(parts)
          valid_parts = parts.compact
          return nil if valid_parts.empty?

          tui.text_line(spans: [
            tui.text_span(content: "  #{valid_parts.join(" | ")}")
          ])
        end

        def format_item_amount(amount)
          return nil if amount.nil? || amount.to_s.strip.empty?

          @app.format_amount(amount, @invoice.currency)
        end

        def format_vat_rate(value)
          return nil if value.nil? || value.to_s.strip.empty?
          return value if value.to_s.include?("%")

          "#{value}%"
        end
      end
    end
  end
end
