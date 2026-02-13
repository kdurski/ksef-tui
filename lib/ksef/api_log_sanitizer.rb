# frozen_string_literal: true

require "json"

module Ksef
  class ApiLogSanitizer
    REDACTED_VALUE = "[REDACTED]"
    REDACTED_BEARER_VALUE = "Bearer [REDACTED]"
    SENSITIVE_HEADER_KEY_PATTERN = /(authorization|cookie|set-cookie|api[-_]?key|token|secret|password)/i
    SENSITIVE_BODY_KEY_PATTERN = /(token|password|secret|authorization|cookie|api[-_]?key)/i

    class << self
      def sanitize_headers(headers)
        return {} if headers.nil?

        headers.each_with_object({}) do |(key, value), memo|
          memo[key] = sanitize_header_value(key, value)
        end
      end

      def sanitize_body(body)
        return nil if body.nil? || body.empty?

        content = body.to_s

        if content.strip.start_with?("{", "[")
          begin
            json = JSON.parse(content)
            redact_json(json).to_json
          rescue JSON::ParserError
            sanitize_text(content)
          end
        else
          sanitize_text(content)
        end
      end

      private

      def sanitize_header_value(key, value)
        string_value = value.to_s

        return REDACTED_BEARER_VALUE if string_value.match?(/\ABearer\s+/i)
        return REDACTED_VALUE if key.to_s.match?(SENSITIVE_HEADER_KEY_PATTERN)

        sanitize_text(string_value)
      end

      def redact_json(data)
        case data
        when Hash
          data.each_with_object({}) do |(k, v), memo|
            memo[k] = if sensitive_key?(k)
              if v.is_a?(Hash) || v.is_a?(Array)
                redact_json(v)
              else
                REDACTED_VALUE
              end
            else
              redact_json(v)
            end
          end
        when Array
          data.map { |item| redact_json(item) }
        when String
          sanitize_text(data)
        else
          data
        end
      end

      def sensitive_key?(key)
        key.to_s.match?(SENSITIVE_BODY_KEY_PATTERN)
      end

      def sanitize_text(text)
        redacted = text.gsub(/Bearer\s+[^\s,;"]+/i, REDACTED_BEARER_VALUE)
        redacted = redacted.gsub(
          /((?:token|password|secret|api[-_]?key|authorization|cookie)\s*[=:]\s*)[^\s,;]+/i,
          "\\1#{REDACTED_VALUE}"
        )
        redacted.gsub(
          /("?(?:token|password|secret|api[-_]?key|authorization|cookie)"?\s*:\s*")([^"]+)(")/i,
          "\\1#{REDACTED_VALUE}\\3"
        )
      end
    end
  end
end
