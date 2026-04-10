module Ksef
  class DbLogger
    def info(message)
      Rails.logger.info("[KSeF] #{message}")
    end

    def error(message)
      Rails.logger.error("[KSeF] #{message}")
    end

    def log_api(log_entry)
      KsefApiLog.create!(
        timestamp: log_entry.timestamp,
        http_method: log_entry.http_method,
        path: log_entry.path,
        status: log_entry.status,
        duration: log_entry.duration,
        request_headers: log_entry.request_headers,
        request_body: log_entry.request_body,
        response_headers: log_entry.response_headers,
        response_body: log_entry.response_body,
        error: log_entry.error.is_a?(Exception) ? log_entry.error.message : log_entry.error.to_s
      )
    rescue => e
      Rails.logger.error("Failed to save KSeF API Log: #{e.message}")
    end
  end
end
