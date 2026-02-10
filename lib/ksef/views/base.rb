# frozen_string_literal: true

module Ksef
  module Views
    # Abstract base class for all views
    class Base
      attr_reader :app

      def initialize(app)
        @app = app
      end

      # Render the view into the given frame
      # @param frame [RatatuiRuby::Frame]
      # @param area [RatatuiRuby::Rect, nil]
      def render(frame, area)
        raise NotImplementedError
      end

      # Handle keyboard input
      # @param event [Hash] parsed event
      # @return [Symbol, nil] :quit or nil
      def handle_input(event)
        raise NotImplementedError
      end

      protected

      def tui
        @app.instance_variable_get(:@tui)
      end
      
      # Helper aliases
      def logger
        @app.logger
      end
      
      def session
        @app.session
      end
    end
  end
end
