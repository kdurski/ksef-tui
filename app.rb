# frozen_string_literal: true

require 'bundler/setup'
require 'dotenv'
require 'ratatui_ruby'

require_relative 'lib/ksef/views/base'
require_relative 'lib/ksef/views/main'
require_relative 'lib/ksef/views/detail'
require_relative 'lib/ksef/views/debug'
require_relative 'lib/ksef/models/invoice'
require_relative 'lib/ksef/logger'
require_relative 'lib/ksef/session'
require_relative 'lib/ksef/client'
require_relative 'lib/ksef/auth'
require_relative 'lib/ksef/helpers'
require_relative 'lib/ksef/tui/styles'

# Only load .env files when not in test mode
Dotenv.load('.env.local', '.env') unless ENV['RACK_ENV'] == 'test' || $PROGRAM_NAME.include?('test')

# KSeF Invoice Viewer TUI Application
class KsefApp
  include Ksef::Helpers
  include Ksef::Tui::Styles
  REFRESH_INTERVAL = 30 * 24 * 3600 # 30 days
  MAX_LOG_ENTRIES = 8

  attr_reader :logger, :session, :view_stack
  attr_accessor :invoices, :status, :status_message

  def initialize(client: nil)
    @client = client || Ksef::Client.new
    @invoices = []
    @status = :disconnected
    @status_message = 'Press "c" to connect'
    
    @logger = Ksef::Logger.new(max_size: MAX_LOG_ENTRIES)
    
    @session = nil
    
    # Initialize View Stack
    @view_stack = [] 
    push_view(Ksef::Views::Main.new(self))
    
    log('Application started')
  end

  def run
    RatatuiRuby.run do |tui|
      @tui = tui
      setup_styles
      
      # Main View already pushed in initialize

      loop do
        @tui.draw { |frame| current_view.render(frame, frame.area) }
        result = current_view.handle_input(@tui.poll_event)
        break if result == :quit
      end
    end
  end

  # View Stack Management
  def push_view(view)
    @view_stack.push(view)
  end

  def pop_view
    @view_stack.pop if @view_stack.length > 1
  end

  def current_view
    @view_stack.last
  end

  def log(message)
    @logger.info(message)
  end

  # Public methods for Views to trigger actions
  def trigger_connect
    connect 
  end

  def trigger_refresh
    refresh
  end

  private

  def connect
    log('Connecting to KSeF...')
    @status = :loading
    @status_message = 'Authenticating...'

    # Force a redraw before blocking operation
    @tui&.draw { |frame| current_view&.render(frame, frame.area) }

    auth = Ksef::Auth.new(client: @client)

    log('Authenticating with token...')
    tokens = auth.authenticate
    
    @session = Ksef::Session.new(
      token: tokens[:access_token],
      valid_until: tokens[:valid_until]
    )
    
    @status = :connected
    @status_message = "Connected (valid until #{@session.valid_until})"
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
    return unless @session&.active?
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

    response = @client.post('/invoices/query/metadata', query_body, token: @session.token)

    if response['error']
      log("Error fetching invoices: #{response['error']} - #{response['message']}")
      @invoices = []
    else
      raw_invoices = response['invoices'] || []
      @invoices = raw_invoices.map { |data| Ksef::Models::Invoice.new(data) }
      # Selection logic moved to Views
      log("Fetched #{@invoices.length} invoice(s)")
    end
  rescue SocketError, Timeout::Error, Net::OpenTimeout, Net::ReadTimeout,
         OpenSSL::SSL::SSLError, Errno::ECONNREFUSED, Errno::ECONNRESET => e
    log("ERROR fetching invoices: #{e.message}")
  end


end

# Run the app
KsefApp.new.run if __FILE__ == $PROGRAM_NAME
