# frozen_string_literal: true

require "yaml"
require_relative "models/profile"

module Ksef
  class Configuration
    CONFIG_FILE = File.expand_path("~/.ksef.yml")

    attr_reader :profiles, :default_profile_name, :config_file, :locale

    def initialize(config_file = nil)
      @config_file = config_file || CONFIG_FILE
      @profiles = {}
      @default_profile_name = nil
      @locale = :pl
      load
    end

    def load
      return unless File.exist?(@config_file)

      config = YAML.load_file(@config_file)
      return unless config

      @default_profile_name = config["default"]
      @locale = (config["locale"] || "pl").to_sym

      if config["profiles"].is_a?(Array)
        config["profiles"].each do |profile_data|
          name = profile_data["name"]
          next unless name

          @profiles[name] = Models::Profile.new(
            name: name,
            nip: profile_data["nip"],
            token: profile_data["token"],
            host: profile_data["host"]
          )
        end
      end
    end


    def get_profile(name)
      return nil unless name
      @profiles[name]
    end

    def default_profile
      get_profile(@default_profile_name)
    end

    def profile_names
      @profiles.keys.sort
    end

    def save(profiles, default: nil)
      data = {
        "default" => default,
        "profiles" => profiles.map do |name, config|
          {
            "name" => name,
            "nip" => config[:nip],
            "token" => config[:token],
            "host" => config[:host]
          }.compact
        end
      }

      File.write(@config_file, data.to_yaml)
    end
  end
end
