# frozen_string_literal: true

module Ksef
  # Request/runtime context for explicit dependency passing.
  # This lets Rails and TUI provide per-execution config/client without
  # mutating global singleton state.
  class Context
    attr_reader :config, :client, :profile_name, :host

    def initialize(config: nil, client: nil, profile_name: nil, host: nil)
      @config = config
      @client = client
      @profile_name = profile_name
      @host = host
    end

    def with(config: self.config, client: self.client, profile_name: self.profile_name, host: self.host)
      self.class.new(config: config, client: client, profile_name: profile_name, host: host)
    end
  end
end
