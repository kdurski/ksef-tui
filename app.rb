# frozen_string_literal: true

require "bundler/setup"
require "ratatui_ruby"

require_relative "lib/ksef/models/invoice"
require_relative "lib/ksef/models/api_log"
require_relative "lib/ksef/models/profile"
require_relative "lib/ksef/logger"
require_relative "lib/ksef/config"
require_relative "lib/ksef/client"
require_relative "lib/ksef/auth"
require_relative "lib/ksef/session"
require_relative "lib/ksef/helpers"
require_relative "lib/ksef/styles"
require_relative "lib/ksef/i18n"
require_relative "lib/ksef/views/base"
require_relative "lib/ksef/views/main"
require_relative "lib/ksef/views/detail"
require_relative "lib/ksef/views/debug"
require_relative "lib/ksef/views/api_detail"
require_relative "lib/ksef/views/profile_selector"


# KSeF Invoice Viewer TUI Application
class KsefApp
  include Ksef::Helpers

  REFRESH_INTERVAL = 30 * 24 * 3600 # 30 days
  MAX_LOG_ENTRIES = 8

  attr_reader :logger, :session, :view_stack, :current_profile, :config, :client
  attr_accessor :invoices, :status, :status_message

  def initialize(profile_name = nil, client: nil, config: nil)
    @client_injected = !client.nil?
    @logger = Ksef::Logger.new(max_size: MAX_LOG_ENTRIES)
    @config = config || Ksef.config
    Ksef::I18n.setup(locale: @config.locale)

    @session = nil
    @invoices = []
    @status = :disconnected
    @status_message = Ksef::I18n.t("app.press_connect")
    @view_stack = []

    # If client is injected (tests), use it and bypass profile loading logic partially
    if client
      @client = client
      @current_profile = if profile_name
        @config.select_profile(profile_name)
      else
        @config.current_profile
      end
      push_view(Ksef::Views::Main.new(self))
    elsif profile_name
      profile = @config.select_profile(profile_name)
      if profile
        load_profile(profile)
      else
        @logger.error(Ksef::I18n.t("app.profile_not_found", name: profile_name))
        puts Ksef::I18n.t("app.profile_not_found", name: profile_name)
        exit(1)
      end
    elsif @config.current_profile
      load_profile(@config.current_profile)
    elsif @config.profile_names.any?
      # Show profile selector
      push_view(Ksef::Views::ProfileSelector.new(self, @config.profile_names))
    else
      @logger.error(Ksef::I18n.t("app.no_profiles"))
      puts Ksef::I18n.t("app.no_profiles")
      exit(1)
    end

    log(Ksef::I18n.t("app.started"))
  end

  def select_profile(profile_name)
    profile = @config.select_profile(profile_name)
    if profile
      load_profile(profile)
      # Clear the selector view and push main view
      @view_stack = []
      push_view(Ksef::Views::Main.new(self))
    end
  end

  def open_profile_selector
    push_view(Ksef::Views::ProfileSelector.new(self, @config.profile_names))
  end

  def load_profile(profile)
    @config.select_profile(profile.name)
    @current_profile = profile

    unless @client_injected
      @client = Ksef::Client.new(
        host: profile.host,
        logger: @logger,
        config: @config
      )
    end

    # If we are starting up (no views), push Main view
    push_view(Ksef::Views::Main.new(self)) if @view_stack.empty?
  end

  def run
    RatatuiRuby.run do |tui|
      @tui = tui

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

  def toggle_locale
    new_locale = Ksef::I18n.toggle_locale
    @config.locale = new_locale
    @status_message = Ksef::I18n.t("app.press_connect") if @status == :disconnected
    log(Ksef::I18n.t("app.locale_changed", locale: new_locale))
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
    log(Ksef::I18n.t("app.connecting"))
    @status = :loading
    @status_message = Ksef::I18n.t("app.authenticating")

    # Force a redraw before blocking operation
    @tui&.draw { |frame| current_view&.render(frame, frame.area) }

    log(Ksef::I18n.t("app.auth_with_token"))

    raise Ksef::AuthError, Ksef::I18n.t("app.no_profile_loaded") unless @current_profile

    auth = Ksef::Auth.new(
      client: @client,
      nip: @current_profile.nip,
      access_token: @current_profile.token
    )
    tokens = auth.authenticate

    @session = Ksef::Session.new(
      access_token: tokens[:access_token],
      access_token_valid_until: tokens[:valid_until],
      refresh_token: tokens[:refresh_token],
      refresh_token_valid_until: tokens[:refresh_token_valid_until]
    )

    @status = :connected
    @status_message = Ksef::I18n.t("app.connected_until", time: @session.access_token_valid_until)
    log(Ksef::I18n.t("app.auth_success"))
    fetch_invoices
  rescue SocketError, Timeout::Error,
    OpenSSL::SSL::SSLError, Errno::ECONNREFUSED, Errno::ECONNRESET,
    ArgumentError, Ksef::AuthError => e
    @status = :disconnected
    @status_message = Ksef::I18n.t("app.auth_failed")
    log(Ksef::I18n.t("app.error", message: e.message))
  end

  def refresh
    return unless @session&.active?
    log(Ksef::I18n.t("app.refreshing"))
    fetch_invoices
  end

  def fetch_invoices
    query_body = {
      subjectType: Ksef::Client::SUBJECT_TYPES[:buyer],
      dateRange: {
        dateType: "PermanentStorage",
        from: (Time.now - REFRESH_INTERVAL).iso8601,
        to: Time.now.iso8601
      }
    }

    response = @client.post("/invoices/query/metadata", query_body, access_token: @session.access_token)

    if response["error"]
      log(Ksef::I18n.t("app.fetch_error", error: response["error"], message: response["message"]))
      @invoices = []
    else
      raw_invoices = response["invoices"] || []
      @invoices = raw_invoices.map { |data| Ksef::Models::Invoice.new(data) }
      # Selection logic moved to Views
      log(Ksef::I18n.t("app.fetched", count: @invoices.length))
    end
  rescue SocketError, Timeout::Error,
    OpenSSL::SSL::SSLError, Errno::ECONNREFUSED, Errno::ECONNRESET => e
    log(Ksef::I18n.t("app.fetch_error_network", message: e.message))
  end
end

# Run the app
if __FILE__ == $PROGRAM_NAME
  require "optparse"

  options = {}
  OptionParser.new do |opts|
    opts.on("-p", "--profile PROFILE", "Select profile to use") do |p|
      options[:profile] = p
    end
  end.parse!

  KsefApp.new(options[:profile]).run
end
