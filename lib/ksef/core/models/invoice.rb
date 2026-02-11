# frozen_string_literal: true

require_relative "../services/invoice_find_all_service"
require_relative "../services/invoice_find_service"
require_relative "../current"

module Ksef
  class InvoiceError < StandardError; end

  module Models
    # Wraps the raw invoice hash from KSeF API
    class Invoice
      attr_reader :raw_data

      class << self
        def find(ksef_number:, client: nil)
          resolved_client = resolve_client!(client)
          raw_invoice = Ksef::Services::InvoiceFindService.new(
            client: resolved_client,
            ksef_number: ksef_number
          ).call

          new(raw_invoice)
        end

        def find_all(query_body:, client: nil)
          resolved_client = resolve_client!(client)
          raw_invoices = Ksef::Services::InvoiceFindAllService.new(
            client: resolved_client,
            query_body: query_body
          ).call

          raw_invoices.map { |invoice_data| new(invoice_data) }
        end

        private

        def resolve_client!(client)
          resolved_client = client || Ksef.current_client
          return resolved_client if resolved_client

          raise Ksef::InvoiceError, "Client is required. Set Ksef.current_client or pass client:"
        end
      end

      def initialize(data)
        @raw_data = data || {}
      end

      def ksef_number
        @raw_data["ksefNumber"]
      end

      def invoice_number
        @raw_data["invoiceNumber"]
      end

      def issue_date
        @raw_data["issueDate"]
      end

      def invoicing_date
        @raw_data["invoicingDate"]
      end

      def net_amount
        @raw_data["netAmount"]
      end

      def gross_amount
        @raw_data["grossAmount"]
      end

      def vat_amount
        @raw_data["vatAmount"]
      end

      def currency
        @raw_data["currency"]
      end

      def seller_name
        @raw_data.dig("seller", "name")
      end

      def seller_nip
        @raw_data.dig("seller", "nip")
      end

      def buyer_name
        @raw_data.dig("buyer", "name")
      end

      def buyer_nip
        @raw_data.dig("buyer", "nip")
      end

      def seller_address
        @raw_data.dig("seller", "address")
      end

      def buyer_address
        @raw_data.dig("buyer", "address")
      end

      def invoice_type
        @raw_data["invoiceType"]
      end

      def payment_due_date
        @raw_data["paymentDueDate"]
      end

      def payment_method
        @raw_data["paymentMethod"]
      end

      def items
        value = @raw_data["items"]
        value.is_a?(Array) ? value : []
      end

      def xml_loaded?
        !xml.to_s.strip.empty?
      end

      def data_source
        xml_loaded? ? :xml : :json_fallback
      end

      # Raw XML payload for invoices loaded from GET /invoices/ksef/{ksefNumber}
      def xml
        @raw_data["xml"]
      end

      # For compatibility with View logic that might expect hash access
      def [](key)
        @raw_data[key]
      end

      def dig(*args)
        @raw_data.dig(*args)
      end
    end
  end
end
