# frozen_string_literal: true

module Ksef
  class Logger
    attr_reader :entries, :api_logs, :max_size, :max_api_logs

    def initialize(max_size: 8, max_api_logs: 50)
      @max_size = max_size
      @max_api_logs = max_api_logs
      @entries = []
      @api_logs = []
    end

    def info(message)
      add_entry(message)
    end

    def error(message)
      add_entry("ERROR: #{message}")
    end

    def log_api(log_entry)
      @api_logs << log_entry
      @api_logs.shift while @api_logs.length > @max_api_logs
    end

    private

    def add_entry(message)
      timestamp = Time.now.strftime('%H:%M:%S')
      @entries << "[#{timestamp}] #{message}"
      @entries.shift while @entries.length > @max_size
    end
  end
end
