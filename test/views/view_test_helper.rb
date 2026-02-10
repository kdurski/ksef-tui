# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/ksef/views/main"
require_relative "../../lib/ksef/views/detail"
require_relative "../../lib/ksef/views/debug"
# require_relative '../lib/ksef/models/invoice' # Already required via app.rb or test_helper

module ViewTestHelper
  include RatatuiRuby::TestHelper

  # Mock App to provide context for Views
  class MockApp
    attr_reader :logger
    attr_accessor :invoices, :status, :status_message, :session

    def initialize
      @invoices = []
      @status = :disconnected
      @status_message = "msg"
      @logger = Ksef::Logger.new
      # Ensure api_logs is available on logger
      unless @logger.respond_to?(:api_logs)
        def @logger.api_logs
          []
        end
      end
      @session = nil
      @tui = RatatuiRuby::TUI.new
    end

    def truncate(str, len)
      (str.length > len) ? str[0...len - 3] + "..." : str
    end

    def format_amount(amount, currency)
      sprintf("%.2f %s", amount.to_f / 100, currency)
    end

    def push_view(view)
    end

    def pop_view
    end

    def trigger_connect
    end

    def trigger_refresh
    end
  end

  def setup
    @app = MockApp.new
  end

  def mock_frame
    frame_double = Struct.new(:area, :rendered_widgets).new(
      StubRect.new(width: 80, height: 24),
      []
    )
    def frame_double.render_widget(widget, area)
      rendered_widgets << {widget: widget, area: area}
    end
    frame_double
  end
end
