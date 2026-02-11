# frozen_string_literal: true

require_relative "base"

module Ksef
  module Views
    class Detail < Base
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
        [
          detail_line(Ksef::I18n.t("views.detail.ksef_number"), @invoice["ksefNumber"]),
          detail_line(Ksef::I18n.t("views.detail.invoice_number"), @invoice["invoiceNumber"]),
          "",
          detail_line(Ksef::I18n.t("views.detail.issue_date"), @invoice["issueDate"]),
          detail_line(Ksef::I18n.t("views.detail.invoicing_date"), @invoice["invoicingDate"]),
          "",
          section_header(Ksef::I18n.t("views.detail.seller")),
          detail_line(Ksef::I18n.t("views.detail.name"), @invoice.seller_name),
          detail_line(Ksef::I18n.t("views.detail.nip"), @invoice.seller_nip),
          "",
          section_header(Ksef::I18n.t("views.detail.buyer")),
          detail_line(Ksef::I18n.t("views.detail.name"), @invoice.buyer_name),
          "",
          section_header(Ksef::I18n.t("views.detail.amounts")),
          amount_line(Ksef::I18n.t("views.detail.net"), @invoice["netAmount"], @invoice["currency"]),
          amount_line(Ksef::I18n.t("views.detail.vat"), @invoice["vatAmount"], @invoice["currency"], highlight: false),
          amount_line(Ksef::I18n.t("views.detail.gross"), @invoice["grossAmount"], @invoice["currency"])
        ]
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
    end
  end
end
