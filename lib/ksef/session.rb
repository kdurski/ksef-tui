# frozen_string_literal: true

module Ksef
  class Session
    attr_reader :access_token, :access_token_valid_until, :refresh_token, :refresh_token_valid_until

    def initialize(access_token:, access_token_valid_until:, refresh_token: nil, refresh_token_valid_until: nil)
      @access_token = access_token
      @access_token_valid_until = access_token_valid_until
      @refresh_token = refresh_token
      @refresh_token_valid_until = refresh_token_valid_until
    end

    def active?
      !@access_token.nil? && !expired?
    end

    def expired?
      # Basic check, assumes valid_until is Time/DateTime or parseable
      return false unless @access_token_valid_until

      Time.parse(@access_token_valid_until.to_s) < Time.now
    rescue ArgumentError
      false # If parsing fails, assume not expired (or handle differently)
    end
  end
end
