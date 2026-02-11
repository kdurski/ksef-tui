# frozen_string_literal: true

module Ksef
  module Models
    class Profile
      DEFAULT_HOST = "api.ksef.mf.gov.pl"

      attr_reader :name, :nip, :token, :host

      def initialize(name:, nip:, token:, host: nil)
        @name = name
        @nip = nip
        @token = token
        @host = host || DEFAULT_HOST
      end

      def to_s
        @name
      end
    end
  end
end
