# frozen_string_literal: true

require_relative "../api_log_sanitizer"

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
      class << self
        def from_http(
          timestamp:,
          http_method:,
          path:,
          status:,
          duration:,
          request_headers:,
          request_body:,
          response_headers:,
          response_body:,
          error:,
          sanitizer: Ksef::ApiLogSanitizer
        )
          new(
            timestamp: timestamp,
            http_method: http_method,
            path: path,
            status: status,
            duration: duration,
            request_headers: sanitizer.sanitize_headers(request_headers),
            request_body: sanitizer.sanitize_body(request_body),
            response_headers: sanitizer.sanitize_headers(response_headers),
            response_body: sanitizer.sanitize_body(response_body),
            error: error
          )
        end
      end

      def success?
        status && status >= 200 && status < 300
      end
    end
  end
end
