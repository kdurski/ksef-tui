# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../../lib/ksef/tui/views/main"
require_relative "../../../lib/ksef/tui/views/detail"
require_relative "../../../lib/ksef/tui/views/debug"

module ViewTestHelper
  # Mock App to provide context for Views
  class MockApp
    attr_reader :logger
    attr_accessor :invoices, :status, :status_message, :session, :current_profile, :config, :client

    def initialize
      @invoices = []
      @status = :disconnected
      @status_message = "msg"
      @logger = Ksef::Logger.new
      # Ensure api_logs is available on logger
      unless @logger.respond_to?(:api_logs)
        @logger.instance_variable_set(:@api_logs, [])
        def @logger.api_logs
          @api_logs
        end
      end
      @session = nil
      @config = Struct.new(:default_host, :max_retries, :open_timeout, :read_timeout, :write_timeout)
        .new("api.ksef.mf.gov.pl", 3, 10, 15, 10)
      @client = Struct.new(:host).new("api.ksef.mf.gov.pl")
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

    def connect!
    end

    def refresh!
    end

    def open_profile_selector
    end

    def toggle_locale
    end

    def preview_invoice(invoice)
      invoice
    end
  end

  def setup
    Ksef::I18n.locale = :en
    @app = MockApp.new
  end

  def mock_frame
    frame_double = Struct.new(:area, :rendered_widgets).new(
      StubRect.new(width: 80, height: 24),
      []
    )
    def frame_double.render_widget(widget, area)
      rendered_widgets << { widget: widget, area: area }
    end
    frame_double
  end
end
