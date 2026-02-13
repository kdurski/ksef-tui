# frozen_string_literal: true

require "yaml"


module Ksef
  class Config
    CONFIG_FILE = File.expand_path("~/.ksef.yml")
    DEFAULT_HOST = Ksef::Models::Profile::DEFAULT_HOST
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
      @default_profile_name = resolve_profile_key(@default_profile_name)
      @current_profile_name = resolve_profile_key(@current_profile_name, fallback: @default_profile_name)
      @current_profile_name ||= @profiles.first&.id
    end

    def get_profile(key)
      return nil unless key

      key = key.to_s
      @profiles.find { |profile| profile.id == key } ||
        @profiles.find { |profile| profile.name == key }
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

    def select_profile(key)
      profile = get_profile(key)
      return nil unless profile

      @current_profile_name = profile.id
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
      @default_profile_name = resolve_profile_key(default || @default_profile_name)
      @current_profile_name = resolve_profile_key(@current_profile_name, fallback: @default_profile_name)

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
            "id" => profile.id,
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
          build_profile({ "name" => name }.merge(profile_hash))
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
        id: profile_data["id"] || profile_data[:id],
        name: name,
        nip: profile_data["nip"] || profile_data[:nip],
        token: profile_data["token"] || profile_data[:token],
        host: profile_data["host"] || profile_data[:host] || @default_host
      )
    end

    def resolve_profile_key(key, fallback: nil)
      return fallback if key.nil?

      profile = get_profile(key)
      profile ? profile.id : fallback
    end
  end
end
