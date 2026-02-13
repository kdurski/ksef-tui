# frozen_string_literal: true

require "openssl"
require "base64"
require "time"

module Ksef
  # Authentication helper for KSeF API
  class AuthError < StandardError; end

  class Auth
    DEFAULT_AUTH_STATUS_MAX_ATTEMPTS = 10
    AUTH_STATUS_POLL_INTERVAL = 1

    attr_reader :client, :nip

    def initialize(client:, nip:, access_token:)
      @client = client
      @nip = nip.to_s.gsub(/\D/, "")
      @access_token = access_token
      validate_credentials!
    end

    # Full authentication flow - returns access_token hash
    # Raises AuthError on failure
    def authenticate
      # Step 1: Get public certificate
      cert = fetch_encryption_certificate

      public_key = cert.public_key

      # Step 2: Get challenge
      challenge_resp = ensure_hash_response!(client.post("/auth/challenge", {}, access_token: nil), "Challenge")
      raise AuthError, "Challenge failed: #{challenge_resp["error"]}" if challenge_resp["error"]

      challenge = require_value!(challenge_resp["challenge"], "Challenge response missing challenge")
      timestamp_ms = parse_challenge_timestamp_ms(challenge_resp)

      # Step 3: Encrypt token
      encrypted_token = encrypt_token(public_key, access_token, timestamp_ms)

      # Step 4: Authenticate
      login_body = {
        contextIdentifier: { type: "Nip", value: nip },
        challenge: challenge,
        encryptedToken: encrypted_token
      }
      auth_resp = ensure_hash_response!(client.post("/auth/ksef-token", login_body, access_token: nil), "Auth")

      raise AuthError, "Auth failed: #{auth_resp["error"]}" if auth_resp["error"]
      auth_token_data = require_hash_value!(auth_resp["authenticationToken"], "No auth token in response")
      auth_token = require_value!(auth_token_data["token"], "No auth token in response")
      reference_number = require_value!(auth_resp["referenceNumber"], "No reference number in response")

      # Step 5: Wait for auth to complete
      raise AuthError, "Auth status check failed" unless wait_for_auth(reference_number, auth_token)

      # Step 6: Redeem tokens
      redeem_resp = ensure_hash_response!(client.post("/auth/token/redeem", {}, access_token: auth_token), "Token redeem")
      raise AuthError, "Token redeem failed: #{redeem_resp["error"]}" if redeem_resp["error"]
      access_token_data = require_hash_value!(redeem_resp["accessToken"], "No access token in response")
      access_token_value = require_value!(access_token_data["token"], "No access token in response")
      refresh_token_data = optional_hash_value(redeem_resp["refreshToken"])

      {
        access_token: access_token_value,
        refresh_token: refresh_token_data["token"],
        valid_until: access_token_data["validUntil"],
        refresh_token_valid_until: refresh_token_data["validUntil"]
      }.tap do |tokens|
        if client.respond_to?(:update_tokens!)
          client.update_tokens!(
            access_token: tokens[:access_token],
            refresh_token: tokens[:refresh_token],
            access_token_valid_until: tokens[:valid_until],
            refresh_token_valid_until: tokens[:refresh_token_valid_until]
          )
        end
      end
    end

    private

    attr_reader :access_token

    def validate_credentials!
      raise ArgumentError, "nip is required" if nip.nil? || nip.empty?
      raise ArgumentError, "access_token is required" if access_token.nil? || access_token.empty?
    end

    def ensure_hash_response!(response, context)
      raise AuthError, "#{context} response is invalid" unless response.is_a?(Hash)

      response
    end

    def require_hash_value!(value, message)
      raise AuthError, message unless value.is_a?(Hash)

      value
    end

    def require_value!(value, message)
      raise AuthError, message if missing?(value)

      value
    end

    def optional_hash_value(value)
      value.is_a?(Hash) ? value : {}
    end

    def missing?(value)
      value.nil? || (value.respond_to?(:empty?) && value.empty?)
    end

    def parse_challenge_timestamp_ms(challenge_resp)
      timestamp_ms = challenge_resp["timestampMs"]
      return timestamp_ms unless timestamp_ms.nil?

      timestamp = challenge_resp["timestamp"]
      raise AuthError, "Challenge response missing timestamp" if timestamp.nil?

      begin
        (Time.parse(timestamp).to_f * 1000).to_i
      rescue ArgumentError, TypeError
        raise AuthError, "Invalid challenge timestamp: #{timestamp.inspect}"
      end
    end

    def fetch_encryption_certificate
      certs = client.get("/security/public-key-certificates", access_token: nil)
      if certs.is_a?(Hash) && certs["error"]
        raise AuthError, "Certificate fetch failed: #{certs["error"]}"
      end
      raise AuthError, "Invalid certificate response" unless certs.is_a?(Array)

      cert_info = certs.find { |c| c["usage"]&.include?("KsefTokenEncryption") }
      raise AuthError, "No encryption certificate found" unless cert_info

      cert_der = Base64.decode64(cert_info["certificate"])
      cert = OpenSSL::X509::Certificate.new(cert_der)
      raise AuthError, "Encryption certificate expired on #{cert.not_after}" if cert.not_after < Time.now
      cert
    end

    def encrypt_token(public_key, token_value, timestamp_ms)
      data = "#{token_value}|#{timestamp_ms}"
      encrypted = public_key.encrypt(data, {
        rsa_padding_mode: "oaep",
        rsa_oaep_md: "sha256",
        rsa_mgf1_md: "sha256"
      })
      Base64.strict_encode64(encrypted)
    end

    def wait_for_auth(reference_number, auth_token, max_attempts: DEFAULT_AUTH_STATUS_MAX_ATTEMPTS)
      max_attempts.times do
        response = client.get("/auth/#{reference_number}", access_token: auth_token)

        if response["error"]
          # Log error? Or just keep polling?
          # If it's a 4xx, it's likely fatal. If 5xx, retry logic in Client logic handles retries.
          # If we are here, retries exhausted?
          # Let's assume we can't really recover if status check fails consistently.
          return false
        end

        status_code = response.dig("status", "code")

        case status_code
        when 200 then return true
        when 400..599 then return false
        end

        sleep AUTH_STATUS_POLL_INTERVAL
      end
      false
    end
  end
end
