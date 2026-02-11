# frozen_string_literal: true

require "yaml"
require_relative "models/profile"
require_relative "current"

module Ksef
  class Config
    CONFIG_FILE = File.expand_path("~/.ksef.yml")
    DEFAULT_HOST = Models::Profile::DEFAULT_HOST
    DEFAULT_MAX_RETRIES = 3
    DEFAULT_OPEN_TIMEOUT = 10
    DEFAULT_READ_TIMEOUT = 15
    DEFAULT_WRITE_TIMEOUT = 10
    DEFAULT_LOCALE = :pl

    class << self
      def default
        @default ||= new
      end

      attr_writer :default
    end

    attr_accessor :profiles, :default_profile_name, :current_profile_name,
      :locale, :default_host, :max_retries, :open_timeout, :read_timeout, :write_timeout
    attr_reader :config_file

    def initialize(config_file = nil)
      @config_file = config_file || CONFIG_FILE
      reset_defaults!
      load
    end

    def load
      return unless File.exist?(@config_file)

      file_content = YAML.safe_load_file(@config_file, aliases: true)
      return unless file_content.is_a?(Hash)

      settings = file_content["settings"]
      settings = {} unless settings.is_a?(Hash)

      @default_profile_name = file_content["default_profile"] || file_content["default"] || @default_profile_name
      @current_profile_name = file_content["current_profile"] || @default_profile_name

      @locale = parse_locale(settings["locale"] || file_content["locale"] || @locale)
      @default_host = settings["default_host"] || settings["host"] || file_content["host"] || @default_host
      @max_retries = parse_integer(settings["max_retries"], @max_retries)
      @open_timeout = parse_integer(settings["open_timeout"], @open_timeout)
      @read_timeout = parse_integer(settings["read_timeout"], @read_timeout)
      @write_timeout = parse_integer(settings["write_timeout"], @write_timeout)

      @profiles = normalize_profiles(file_content["profiles"] || [])
      @current_profile_name = @default_profile_name unless get_profile(@current_profile_name)
      @current_profile_name ||= @profiles.first&.name
    end

    def get_profile(name)
      return nil unless name
      @profiles.find { |profile| profile.name == name }
    end

    def default_profile
      get_profile(@default_profile_name)
    end

    def current_profile
      get_profile(@current_profile_name) || default_profile
    end

    def profile_names
      @profiles.map(&:name).sort
    end

    def select_profile(name)
      profile = get_profile(name)
      return nil unless profile

      @current_profile_name = profile.name
      profile
    end

    def network_settings
      {
        max_retries: @max_retries,
        open_timeout: @open_timeout,
        read_timeout: @read_timeout,
        write_timeout: @write_timeout
      }
    end

    def save(profiles = nil, default: nil)
      @profiles = normalize_profiles(profiles) if profiles
      @default_profile_name = default if default
      @current_profile_name ||= @default_profile_name

      data = {
        "settings" => {
          "locale" => @locale.to_s,
          "default_host" => @default_host,
          "max_retries" => @max_retries,
          "open_timeout" => @open_timeout,
          "read_timeout" => @read_timeout,
          "write_timeout" => @write_timeout
        },
        "default_profile" => @default_profile_name,
        "current_profile" => @current_profile_name,
        "profiles" => @profiles.map do |profile|
          {
            "name" => profile.name,
            "nip" => profile.nip,
            "token" => profile.token,
            "host" => profile.host
          }.compact
        end
      }

      File.write(@config_file, data.to_yaml)
    end

    private

    def reset_defaults!
      @profiles = []
      @default_profile_name = nil
      @current_profile_name = nil
      @locale = DEFAULT_LOCALE
      @default_host = DEFAULT_HOST
      @max_retries = DEFAULT_MAX_RETRIES
      @open_timeout = DEFAULT_OPEN_TIMEOUT
      @read_timeout = DEFAULT_READ_TIMEOUT
      @write_timeout = DEFAULT_WRITE_TIMEOUT
    end

    def parse_locale(locale)
      locale.to_s.empty? ? DEFAULT_LOCALE : locale.to_sym
    end

    def parse_integer(value, fallback)
      Integer(value)
    rescue ArgumentError, TypeError
      fallback
    end

    def normalize_profiles(raw_profiles)
      case raw_profiles
      when Hash
        raw_profiles.map do |name, profile_data|
          profile_hash = profile_data.is_a?(Hash) ? profile_data.transform_keys(&:to_s) : {}
          build_profile({"name" => name}.merge(profile_hash))
        end.compact
      when Array
        raw_profiles.map { |profile_data| build_profile(profile_data) }.compact
      else
        []
      end
    end

    def build_profile(profile_data)
      return nil unless profile_data.is_a?(Hash)

      name = profile_data["name"] || profile_data[:name]
      return nil if name.to_s.strip.empty?

      Models::Profile.new(
        name: name,
        nip: profile_data["nip"] || profile_data[:nip],
        token: profile_data["token"] || profile_data[:token],
        host: profile_data["host"] || profile_data[:host] || @default_host
      )
    end
  end
end

module Ksef
  class << self
    def config
      Config.default
    end

    def config=(value)
      Config.default = value
    end

    def configure(config_file: nil)
      self.config = Config.new(config_file)
      yield(config) if block_given?
      config
    end

    def current_client
      Current.client
    end

    def current_client=(client)
      Current.client = client
    end
  end
end
