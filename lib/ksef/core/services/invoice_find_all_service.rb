# frozen_string_literal: true

module Ksef
  module Services
    class InvoiceFindAllService
      def initialize(client:, query_body:)
        @client = client
        @query_body = query_body
      end

      def call
        raise Ksef::InvoiceError, "query_body must be a Hash" unless @query_body.is_a?(Hash)

        response = @client.post("/invoices/query/metadata", @query_body)
        raise Ksef::InvoiceError, response["error"] if response.is_a?(Hash) && response["error"]
        raise Ksef::InvoiceError, "Invalid invoice list response" unless response.is_a?(Hash)

        raw_invoices = response["invoices"] || []
        raise Ksef::InvoiceError, "Invalid invoices payload" unless raw_invoices.is_a?(Array)

        raw_invoices.map { |invoice| normalize_invoice_data(invoice) }
      end

      private

      def normalize_invoice_data(invoice)
        raise Ksef::InvoiceError, "Invalid invoice entry" unless invoice.is_a?(Hash)

        deep_stringify_keys(invoice)
      end

      def deep_stringify_keys(value)
        case value
        when Hash
          value.each_with_object({}) do |(key, nested_value), memo|
            memo[key.to_s] = deep_stringify_keys(nested_value)
          end
        when Array
          value.map { |item| deep_stringify_keys(item) }
        else
          value
        end
      end
    end
  end
end
