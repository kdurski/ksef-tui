# frozen_string_literal: true

module Ksef
  module Models
    # Struct to hold API request/response details
    ApiLog = Struct.new(
      :timestamp,
      :http_method,
      :path,
      :status,
      :duration,
      :request_headers,
      :request_body,
      :response_headers,
      :response_body,
      :error,
      keyword_init: true
    ) do
      def success?
        status && status >= 200 && status < 300
      end
    end
  end
end
