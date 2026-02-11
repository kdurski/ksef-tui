# frozen_string_literal: true

require "net/http"
require "openssl"
require "uri"
require "json"

# KSeF API client for interacting with the Polish National e-Invoice System
module Ksef
  class Client
    BASE_PATH = "/v2"
    DEFAULT_HOST = "api.ksef.mf.gov.pl"
    DEFAULT_MAX_RETRIES = 3
    DEFAULT_OPEN_TIMEOUT = 10
    DEFAULT_READ_TIMEOUT = 15
    DEFAULT_WRITE_TIMEOUT = 10
    DEFAULT_RETRY_BACKOFF_BASE = 0.2
    SUBJECT_TYPES = {
      seller: "Subject1",
      buyer: "Subject2",
      authorized: "SubjectAuthorized"
    }.freeze

    attr_reader :host, :logger, :max_retries, :open_timeout, :read_timeout, :write_timeout

    def initialize(
      host: nil,
      logger: nil,
      config: nil,
      max_retries: nil,
      open_timeout: nil,
      read_timeout: nil,
      write_timeout: nil
    )
      config ||= Ksef.config

      @host = host || config&.default_host || DEFAULT_HOST
      @logger = logger
      @max_retries = parse_integer(max_retries, config&.max_retries || DEFAULT_MAX_RETRIES)
      @open_timeout = parse_integer(open_timeout, config&.open_timeout || DEFAULT_OPEN_TIMEOUT)
      @read_timeout = parse_integer(read_timeout, config&.read_timeout || DEFAULT_READ_TIMEOUT)
      @write_timeout = parse_integer(write_timeout, config&.write_timeout || DEFAULT_WRITE_TIMEOUT)
    end

    # Perform a POST request to the KSeF API
    def post(path, body = {}, access_token: nil)
      request(:post, path, body: body, token: access_token)
    end

    # Perform a GET request to the KSeF API
    def get(path, access_token: nil)
      request(:get, path, token: access_token)
    end

    private

    def base_url
      "https://#{host}#{BASE_PATH}"
    end

    class ServerError < StandardError
      attr_reader :response
      def initialize(response)
        @response = response
        super("HTTP #{response.code}")
      end
    end
    private_constant :ServerError

    def request(method, path, body: nil, token: nil)
      uri = URI("#{base_url}#{path}")
      http = build_http(uri)
      headers = build_headers(method, token)
      req = build_request(method, uri, headers)
      req.body = body.to_json if body && method == :post

      start_time = Time.now
      response = nil
      error = nil

      begin
        parsed_response, response, error = perform_request_with_retries(http, req)
        parsed_response
      ensure
        log_api_request(
          start_time: start_time,
          method: method,
          path: path,
          headers: headers,
          request_body: req.body,
          response: response,
          error: error
        )
      end
    end

    def perform_request_with_retries(http, req)
      retries = 0

      begin
        response = http.request(req)
        raise ServerError.new(response) if response.code.to_i >= 500

        [parse_response(response), response, nil]
      rescue SocketError, Timeout::Error,
        OpenSSL::SSL::SSLError, Errno::ECONNREFUSED, Errno::ECONNRESET,
        ServerError => e

        if retries < @max_retries
          retries += 1
          sleep(DEFAULT_RETRY_BACKOFF_BASE * (2**retries))
          retry
        end

        return [parse_response(e.response), e.response, e] if e.is_a?(ServerError)

        raise
      end
    end

    def log_api_request(start_time:, method:, path:, headers:, request_body:, response:, error:)
      return unless @logger

      duration = Time.now - start_time
      resp_body = response ? response.body : error&.message

      log_entry = Ksef::Models::ApiLog.from_http(
        timestamp: start_time,
        http_method: method.upcase,
        path: path,
        status: response ? response.code.to_i : 0,
        duration: duration,
        request_headers: headers,
        request_body: request_body,
        response_headers: response ? response.each_header.to_h : {},
        response_body: resp_body,
        error: error
      )
      @logger.log_api(log_entry)
    end

    def build_http(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.open_timeout = @open_timeout.to_i
      http.read_timeout = @read_timeout.to_i
      http.write_timeout = @write_timeout.to_i
      http
    end

    def build_headers(method, token)
      headers = {"Accept" => "application/json"}
      headers["Content-Type"] = "application/json" if method == :post
      headers["Authorization"] = "Bearer #{token}" if token
      headers
    end

    def build_request(method, uri, headers)
      request_uri = uri.request_uri

      case method
      when :get then Net::HTTP::Get.new(request_uri, headers)
      when :post then Net::HTTP::Post.new(request_uri, headers)
      end
    end

    def parse_response(response)
      return {"error" => "Empty response (HTTP #{response.code})"} if response.body.nil? || response.body.empty?

      parsed = JSON.parse(response.body)

      unless response.is_a?(Net::HTTPSuccess)
        payload = parsed.is_a?(Hash) ? parsed : {"body" => parsed}
        payload["http_status"] = response.code.to_i
        payload["error"] ||= "HTTP #{response.code}"
        return payload
      end

      parsed
    rescue JSON::ParserError
      {"error" => "Invalid JSON response (HTTP #{response.code})", "body" => response.body}
    end

    def parse_integer(value, fallback)
      return fallback if value.nil?

      Integer(value)
    rescue ArgumentError, TypeError
      fallback
    end
  end
end
