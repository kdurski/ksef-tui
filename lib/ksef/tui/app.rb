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

        @session = nil
        @invoices = []
        @status = :disconnected
        @status_message = Ksef::I18n.t("app.press_connect")
        @view_stack = []

        if client
          @client = client
          @current_profile = if profile_name
            @config.select_profile(profile_name)
          else
            @config.current_profile
          end
          push_view(Ksef::Tui::Views::Main.new(self))
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
          push_view(Ksef::Tui::Views::ProfileSelector.new(self, @config.profile_names))
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

      private

      def reset_runtime_state!
        @session = nil
        @invoices = []
        @status = :disconnected
        @status_message = Ksef::I18n.t("app.press_connect")
      end

      def connect
        log(Ksef::I18n.t("app.connecting"))
        @status = :loading
        @status_message = Ksef::I18n.t("app.authenticating")

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
          log(Ksef::I18n.t("app.fetched", count: @invoices.length))
        end
      rescue SocketError, Timeout::Error,
        OpenSSL::SSL::SSLError, Errno::ECONNREFUSED, Errno::ECONNRESET => e
        log(Ksef::I18n.t("app.fetch_error_network", message: e.message))
      end
    end
  end
end
