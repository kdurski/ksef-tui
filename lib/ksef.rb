# frozen_string_literal: true

module Ksef
  class << self
    def config
      # Prefer per-request/per-execution context when available.
      # Fallback keeps TUI and other non-Rails entrypoints working.
      Current.context&.config || Config.default
    end

    def config=(value)
      if Current.context
        # When running inside an explicit context, mutate only that context.
        Current.context = Current.context.with(config: value)
      else
        Config.default = value
      end
    end

    def configure(config_file: nil)
      self.config = Config.new(config_file)
      yield(config) if block_given?
      config
    end

    def current_client
      # Same precedence rule as config: context first, global fallback second.
      Current.context&.client || Current.client
    end

    def current_client=(client)
      Current.client = client
      Current.context = Current.context.with(client: client) if Current.context
    end

    def context
      Current.context
    end

    def context=(context)
      Current.context = context
      Current.client = context&.client
    end

    def with_context(context)
      Current.with_context(context) { yield }
    end
  end
end
