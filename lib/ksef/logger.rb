# frozen_string_literal: true

module Ksef
  class Logger
    attr_reader :entries, :max_size

    def initialize(max_size: 8)
      @max_size = max_size
      @entries = []
    end

    def info(message)
      add_entry(message)
    end

    def error(message)
      add_entry("ERROR: #{message}")
    end

    private

    def add_entry(message)
      timestamp = Time.now.strftime('%H:%M:%S')
      @entries << "[#{timestamp}] #{message}"
      @entries.shift while @entries.length > @max_size
    end
  end
end
