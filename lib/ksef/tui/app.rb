# frozen_string_literal: true

require "ratatui_ruby"

require_relative "../core/models/invoice"
require_relative "../core/models/api_log"
require_relative "../core/models/profile"
require_relative "../core/logger"
require_relative "../core/config"
require_relative "../core/client"
require_relative "../core/auth"
require_relative "../core/session"
require_relative "../core/i18n"
require_relative "helpers"
require_relative "styles"
require_relative "views/base"
require_relative "views/main"
require_relative "views/detail"
require_relative "views/debug"
require_relative "views/api_detail"
require_relative "views/profile_selector"

module Ksef
  module Tui
    # KSeF Invoice Viewer TUI Application
    class App
      include Ksef::Tui::Helpers

      REFRESH_INTERVAL = 30 * 24 * 3600 # 30 days
      MAX_LOG_ENTRIES = 8

      attr_reader :logger, :session, :view_stack, :current_profile, :config, :client
      attr_accessor :invoices, :status, :status_message

      def initialize(profile_name = nil, client: nil, config: nil)
        @client_injected = !client.nil?
        @logger = Ksef::Logger.new(max_size: MAX_LOG_ENTRIES)
        @config = config || Ksef.config
        Ksef::I18n.setup(locale: @config.locale)

        initialize_runtime_state!
        setup_initial_view(profile_name, client)

        log(Ksef::I18n.t("app.started"))
      end

      def select_profile(profile_name)
        profile = @config.select_profile(profile_name)
        if profile
          profile_changed = @current_profile&.name != profile.name
          reset_runtime_state! if profile_changed
          load_profile(profile)
          @view_stack = []
          push_view(Ksef::Tui::Views::Main.new(self))
        end
      end

      def open_profile_selector
        push_view(Ksef::Tui::Views::ProfileSelector.new(self, @config.profile_names))
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

        Ksef.current_client = @client

        push_view(Ksef::Tui::Views::Main.new(self)) if @view_stack.empty?
      end

      def run
        RatatuiRuby.run do |tui|
          @tui = tui

          loop do
            @tui.draw { |frame| current_view.render(frame, frame.area) }
            result = current_view.handle_input(@tui.poll_event)
            break if result == :quit
          end
        end
      end

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

      def connect!
        connect
      end

      def refresh!
        refresh
      end

      def preview_invoice(invoice)
        return nil unless invoice
        return invoice if invoice.xml

        ksef_number = invoice.ksef_number
        return invoice if ksef_number.nil? || ksef_number.empty?
        return invoice unless @client&.access_token

        Ksef::Models::Invoice.find(ksef_number: ksef_number, client: @client)
      rescue => e
        log("ERROR loading invoice preview: #{e.message}")
        invoice
      end

      private

      def initialize_runtime_state!
        @session = nil
        @invoices = []
        @status = :disconnected
        @status_message = Ksef::I18n.t("app.press_connect")
        @view_stack = []
      end

      def setup_initial_view(profile_name, client)
        return setup_with_injected_client(profile_name, client) if client
        return setup_with_selected_profile(profile_name) if profile_name
        return load_profile(@config.current_profile) if @config.current_profile
        return open_profile_selector if @config.profile_names.any?

        exit_with_message("app.no_profiles")
      end

      def setup_with_injected_client(profile_name, client)
        @client = client
        Ksef.current_client = @client
        @current_profile = profile_name ? @config.select_profile(profile_name) : @config.current_profile
        push_main_view
      end

      def setup_with_selected_profile(profile_name)
        profile = @config.select_profile(profile_name)
        return load_profile(profile) if profile

        exit_with_message("app.profile_not_found", name: profile_name)
      end

      def push_main_view
        push_view(Ksef::Tui::Views::Main.new(self))
      end

      def exit_with_message(key, **args)
        message = Ksef::I18n.t(key, **args)
        @logger.error(message)
        puts message
        exit(1)
      end

      def reset_runtime_state!
        @session = nil
        @invoices = []
        @status = :disconnected
        @status_message = Ksef::I18n.t("app.press_connect")
      end

      def connect
        begin_connect_flow!
        validate_current_profile!

        tokens = authenticate_current_profile
        establish_session(tokens)
        finalize_connect!
        fetch_invoices
      rescue SocketError, Timeout::Error,
        OpenSSL::SSL::SSLError, Errno::ECONNREFUSED, Errno::ECONNRESET,
        ArgumentError, Ksef::AuthError => e
        handle_connect_error(e)
      end

      def begin_connect_flow!
        log(Ksef::I18n.t("app.connecting"))
        @status = :loading
        @status_message = Ksef::I18n.t("app.authenticating")

        @tui&.draw { |frame| current_view&.render(frame, frame.area) }

        log(Ksef::I18n.t("app.auth_with_token"))
      end

      def validate_current_profile!
        raise Ksef::AuthError, Ksef::I18n.t("app.no_profile_loaded") unless @current_profile
      end

      def authenticate_current_profile
        auth = Ksef::Auth.new(
          client: @client,
          nip: @current_profile.nip,
          access_token: @current_profile.token
        )
        auth.authenticate
      end

      def establish_session(tokens)
        @session = Ksef::Session.new(
          access_token: tokens[:access_token],
          access_token_valid_until: tokens[:valid_until],
          refresh_token: tokens[:refresh_token],
          refresh_token_valid_until: tokens[:refresh_token_valid_until]
        )
        if @client.respond_to?(:update_tokens!)
          @client.update_tokens!(
            access_token: @session.access_token,
            refresh_token: @session.refresh_token,
            access_token_valid_until: @session.access_token_valid_until,
            refresh_token_valid_until: @session.refresh_token_valid_until
          )
        end
      end

      def finalize_connect!
        @status = :connected
        @status_message = Ksef::I18n.t("app.connected_until", time: @session.access_token_valid_until)
        log(Ksef::I18n.t("app.auth_success"))
      end

      def handle_connect_error(error)
        @status = :disconnected
        @status_message = Ksef::I18n.t("app.auth_failed")
        log(Ksef::I18n.t("app.error", message: error.message))
      end

      def refresh
        return unless @session&.active?

        log(Ksef::I18n.t("app.refreshing"))
        fetch_invoices
      end

      def fetch_invoices
        @invoices = Ksef::Models::Invoice.find_all(query_body: invoices_query_body, client: @client)
        log(Ksef::I18n.t("app.fetched", count: @invoices.length))
      rescue Ksef::InvoiceError => e
        log(Ksef::I18n.t("app.fetch_error", error: e.message, message: nil))
        @invoices = []
      rescue SocketError, Timeout::Error,
        OpenSSL::SSL::SSLError, Errno::ECONNREFUSED, Errno::ECONNRESET => e
        log(Ksef::I18n.t("app.fetch_error_network", message: e.message))
      end

      def invoices_query_body
        {
          subjectType: Ksef::Client::SUBJECT_TYPES[:buyer],
          dateRange: {
            dateType: "PermanentStorage",
            from: (Time.now - REFRESH_INTERVAL).iso8601,
            to: Time.now.iso8601
          }
        }
      end
    end
  end
end
