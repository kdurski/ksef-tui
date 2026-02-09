# frozen_string_literal: true

require 'bundler/setup'
require 'dotenv'
require 'ratatui_ruby'
require_relative 'lib/ksef/client'
require_relative 'lib/ksef/auth'
require_relative 'lib/ksef/helpers'
require_relative 'lib/ksef/tui/styles'
require_relative 'lib/ksef/tui/views'
require_relative 'lib/ksef/tui/input_handler'

Dotenv.load('.env.local', '.env')

# KSeF Invoice Viewer TUI Application
class KsefApp
  include Ksef::Helpers
  include Ksef::Tui::Styles
  include Ksef::Tui::Views
  include Ksef::Tui::InputHandler

  REFRESH_INTERVAL = 30 * 24 * 3600 # 30 days
  MAX_LOG_ENTRIES = 8

  def initialize(client: nil, tui: nil)
    @client = client || Ksef::Client.new
    @tui = tui
    @invoices = []
    @selected_index = 0
    @status = :disconnected
    @status_message = 'Press "c" to connect'
    @access_token = nil
    @show_detail = false
    @log_entries = []
    log('Application started')
  end

  def run
    RatatuiRuby.run do |tui|
      @tui = tui
      setup_styles

      loop do
        @tui.draw { |frame| render(frame) }
        break if handle_input == :quit
      end
    end
  end

  def log(message)
    timestamp = Time.now.strftime('%H:%M:%S')
    @log_entries << "[#{timestamp}] #{message}"
    @log_entries.shift while @log_entries.length > MAX_LOG_ENTRIES
  end

  private

  def connect
    log('Connecting to KSeF...')
    @status = :loading
    @status_message = 'Authenticating...'

    # Force a redraw before blocking operation
    @tui.draw { |frame| render(frame) }

    auth = Ksef::Auth.new(client: @client)

    log('Authenticating with token...')
    tokens = auth.authenticate
    
    @access_token = tokens[:access_token]
    @status = :connected
    @status_message = "Connected (valid until #{tokens[:valid_until]})"
    log('Authentication successful!')
    fetch_invoices
    
  rescue SocketError, Timeout::Error, Net::OpenTimeout, Net::ReadTimeout,
         OpenSSL::SSL::SSLError, Errno::ECONNREFUSED, Errno::ECONNRESET,
         ArgumentError, Ksef::AuthError => e
    @status = :disconnected
    @status_message = 'Connection failed. Press "c" to retry.'
    log("ERROR: #{e.message}")
  end

  def refresh
    return unless @access_token
    log('Refreshing invoice list...')
    fetch_invoices
  end

  def fetch_invoices

    query_body = {
      subjectType: Ksef::Client::SUBJECT_TYPES[:buyer],
      dateRange: {
        dateType: 'PermanentStorage',
        from: (Time.now - REFRESH_INTERVAL).iso8601,
        to: Time.now.iso8601
      }
    }

    response = @client.post('/invoices/query/metadata', query_body, token: @access_token)

    if response['error']
      log("Error fetching invoices: #{response['error']} - #{response['message']}")
      @invoices = []
    else
      @invoices = response['invoices'] || []
      @selected_index = 0 if @selected_index >= @invoices.length
      log("Fetched #{@invoices.length} invoice(s)")
    end
  rescue SocketError, Timeout::Error, Net::OpenTimeout, Net::ReadTimeout,
         OpenSSL::SSL::SSLError, Errno::ECONNREFUSED, Errno::ECONNRESET => e
    log("ERROR fetching invoices: #{e.message}")
  end


end

# Run the app
KsefApp.new.run if __FILE__ == $PROGRAM_NAME
