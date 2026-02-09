# frozen_string_literal: true

require 'net/http'
require 'openssl'
require 'uri'
require 'json'

# KSeF API client for interacting with the Polish National e-Invoice System
module Ksef
  class Client
    BASE_PATH = '/v2'

    SUBJECT_TYPES = {
      seller: 'Subject1',
      buyer: 'Subject2',
      authorized: 'SubjectAuthorized'
    }.freeze

    attr_reader :host

    def initialize(host: ENV.fetch('KSEF_HOST', 'api.ksef.mf.gov.pl'))
      @host = host
    end

    # Perform a POST request to the KSeF API
    def post(path, body = {}, token: nil)
      request(:post, path, body: body, token: token)
    end

    # Perform a GET request to the KSeF API
    def get(path, token: nil)
      request(:get, path, token: token)
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

      retries = 0
      max_retries = ENV.fetch('KSEF_MAX_RETRIES', 3).to_i

      begin
        response = http.request(req)
        raise ServerError.new(response) if response.code.to_i >= 500

        parse_response(response)
      rescue SocketError, Timeout::Error, Net::OpenTimeout, Net::ReadTimeout,
             OpenSSL::SSL::SSLError, Errno::ECONNREFUSED, Errno::ECONNRESET,
             ServerError => e

        if retries < max_retries
          retries += 1
          sleep(0.2 * (2**retries))
          retry
        end

        e.is_a?(ServerError) ? parse_response(e.response) : raise(e)
      end
    end

    def build_http(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.open_timeout = ENV.fetch('KSEF_OPEN_TIMEOUT', 10).to_i
      http.read_timeout = ENV.fetch('KSEF_READ_TIMEOUT', 15).to_i
      http.write_timeout = ENV.fetch('KSEF_WRITE_TIMEOUT', 10).to_i
      http
    end

    def build_headers(method, token)
      headers = { 'Accept' => 'application/json' }
      headers['Content-Type'] = 'application/json' if method == :post
      headers['Authorization'] = "Bearer #{token}" if token
      headers
    end

    def build_request(method, uri, headers)
      case method
      when :get  then Net::HTTP::Get.new(uri.path, headers)
      when :post then Net::HTTP::Post.new(uri.path, headers)
      end
    end

    def parse_response(response)
      return { 'error' => "Empty response (HTTP #{response.code})" } if response.body.nil? || response.body.empty?

      parsed = JSON.parse(response.body)

      unless response.is_a?(Net::HTTPSuccess)
        return parsed.merge('http_status' => response.code.to_i, 'error' => "HTTP #{response.code}")
      end

      parsed
    rescue JSON::ParserError
      { 'error' => "Invalid JSON response (HTTP #{response.code})", 'body' => response.body }
    end
  end
end
