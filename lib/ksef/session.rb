# frozen_string_literal: true

module Ksef
  class Session
    attr_reader :token, :valid_until

    def initialize(token:, valid_until:)
      @token = token
      @valid_until = valid_until
    end

    def active?
      !@token.nil? && !expired?
    end

    def expired?
      # Basic check, assumes valid_until is Time/DateTime or parseable
      return false unless @valid_until
      
      Time.parse(@valid_until.to_s) < Time.now
    rescue ArgumentError
      false # If parsing fails, assume not expired (or handle differently)
    end
  end
end
