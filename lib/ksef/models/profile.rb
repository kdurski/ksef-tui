# frozen_string_literal: true

module Ksef
  module Models
    class Profile
      DEFAULT_HOST = "api.ksef.mf.gov.pl"

      attr_reader :id, :name, :nip, :token, :host

      def initialize(name:, nip:, token:, host: nil, id: nil)
        @id = resolve_id(id, name)
        @name = name
        @nip = nip
        @token = token
        @host = host || DEFAULT_HOST
      end

      def to_s
        @name
      end

      private

      def resolve_id(id, name)
        provided = id.to_s.strip
        return provided unless provided.empty?

        fallback = name.to_s.strip.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
        fallback.empty? ? "profile" : fallback
      end
    end
  end
end
