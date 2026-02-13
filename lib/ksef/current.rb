# frozen_string_literal: true

require "active_support/current_attributes"

module Ksef
  # Request/execution-local state for KSeF integration.
  # Backed by Rails execution isolation via CurrentAttributes.
  class Current < ActiveSupport::CurrentAttributes
    attribute :client, :context

    class << self
      # Convenience wrapper for short-lived client overrides in tests/services.
      def with_client(client)
        set(client: client) { yield }
      end

      # Sets both context and derived client for the block and restores automatically.
      def with_context(context)
        set(context: context, client: context&.client) { yield }
      end
    end
  end
end
