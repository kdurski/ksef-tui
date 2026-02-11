# frozen_string_literal: true

require "openssl"
require "base64"
require "time"

module Ksef
  # Authentication helper for KSeF API
  # Authentication helper for KSeF API
  class AuthError < StandardError; end

  class Auth
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
      challenge_resp = client.post("/auth/challenge")
      raise AuthError, "Challenge failed: #{challenge_resp["error"]}" if challenge_resp["error"]

      challenge = challenge_resp["challenge"]
      timestamp = challenge_resp["timestamp"]
      timestamp_ms = challenge_resp["timestampMs"]
      if timestamp_ms.nil?
        raise AuthError, "Challenge response missing timestamp" if timestamp.nil?

        begin
          timestamp_ms = (Time.parse(timestamp).to_f * 1000).to_i
        rescue ArgumentError, TypeError
          raise AuthError, "Invalid challenge timestamp: #{timestamp.inspect}"
        end
      end

      # Step 3: Encrypt token
      encrypted_token = encrypt_token(public_key, access_token, timestamp_ms)

      # Step 4: Authenticate
      login_body = {
        contextIdentifier: {type: "Nip", value: nip},
        challenge: challenge,
        encryptedToken: encrypted_token
      }
      auth_resp = client.post("/auth/ksef-token", login_body)

      raise AuthError, "Auth failed: #{auth_resp["error"]}" if auth_resp["error"]
      raise AuthError, "No auth token in response" unless auth_resp["authenticationToken"]

      auth_token = auth_resp["authenticationToken"]["token"]
      reference_number = auth_resp["referenceNumber"]

      # Step 5: Wait for auth to complete
      raise AuthError, "Auth status check failed" unless wait_for_auth(reference_number, auth_token)

      # Step 6: Redeem tokens
      redeem_resp = client.post("/auth/token/redeem", {}, access_token: auth_token)
      raise AuthError, "Token redeem failed: #{redeem_resp["error"]}" if redeem_resp["error"]
      access_token_data = redeem_resp["accessToken"]
      raise AuthError, "No access token in response" unless access_token_data.is_a?(Hash) && access_token_data["token"]

      refresh_token_data = redeem_resp["refreshToken"]
      refresh_token_data = {} unless refresh_token_data.is_a?(Hash)

      {
        access_token: access_token_data["token"],
        refresh_token: refresh_token_data["token"],
        valid_until: access_token_data["validUntil"],
        refresh_token_valid_until: refresh_token_data["validUntil"]
      }
    end

    private

    attr_reader :access_token

    def validate_credentials!
      raise ArgumentError, "nip is required" if nip.nil? || nip.empty?
      raise ArgumentError, "access_token is required" if access_token.nil? || access_token.empty?
    end

    def fetch_encryption_certificate
      certs = client.get("/security/public-key-certificates")
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

    def wait_for_auth(reference_number, auth_token, max_attempts: 10)
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

        sleep 1
      end
      false
    end
  end
end
