# frozen_string_literal: true

module Ksef
  module Current
    THREAD_CLIENT_KEY = :ksef_current_client

    class << self
      def client
        Thread.current[THREAD_CLIENT_KEY]
      end

      def client=(value)
        Thread.current[THREAD_CLIENT_KEY] = value
      end

      def with_client(client)
        previous_client = self.client
        self.client = client
        yield
      ensure
        self.client = previous_client
      end
    end
  end
end
