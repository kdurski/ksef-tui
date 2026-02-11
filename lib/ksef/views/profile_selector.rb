# frozen_string_literal: true

require_relative "base"

module Ksef
  module Views
    class ProfileSelector < Base
      def initialize(app, profiles)
        super(app)
        @profiles = profiles # Array of profile names
        @selected_index = 0
      end

      def render(frame, area)
        layout = tui.layout_split(
          area,
          direction: :vertical,
          constraints: [
            tui.constraint_length(3), # Title
            tui.constraint_min(0),    # List
            tui.constraint_length(1)  # Footer
          ]
        )

        # Title
        title = tui.paragraph(
          text: Ksef::I18n.t("views.profile_selector.title"),
          style: Ksef::Styles::TITLE || {fg: :cyan},
          alignment: :center,
          block: tui.block(borders: [:bottom])
        )
        frame.render_widget(title, layout[0])

        # List
        items = @profiles.map.with_index do |name, index|
          style = if index == @selected_index
            Ksef::Styles::HIGHLIGHT || {fg: :yellow}
          else
            {fg: :white}
          end

          prefix = (index == @selected_index) ? "> " : "  "
          tui.list_item(content: "#{prefix}#{name}", style: style)
        end

        list = tui.list(
          items: items,
          block: tui.block(title: Ksef::I18n.t("views.profile_selector.available"), borders: [:all]),
          highlight_style: Ksef::Styles::HIGHLIGHT || {fg: :yellow},
          highlight_symbol: ""
        )

        frame.render_widget(list, layout[1])

        # Footer
        footer = tui.paragraph(
          text: Ksef::I18n.t("views.profile_selector.footer"),
          style: {fg: :blue},
          alignment: :center
        )
        frame.render_widget(footer, layout[2])
      end

      def handle_input(event)
        case event
        in {type: :key, code: "q"} | {type: :key, code: "esc"} | {type: :key, code: "escape"}
          @app.pop_view
        in {type: :key, code: "down"}
          @selected_index = (@selected_index + 1) % @profiles.length if @profiles.any?
        in {type: :key, code: "up"}
          @selected_index = (@selected_index - 1) % @profiles.length if @profiles.any?
        in {type: :key, code: "enter"}
          selected_profile = @profiles[@selected_index]
          @app.select_profile(selected_profile)
        else
          nil
        end
      end
    end
  end
end
