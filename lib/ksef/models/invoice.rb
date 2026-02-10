# frozen_string_literal: true

module Ksef
  module Models
    # Wraps the raw invoice hash from KSeF API
    class Invoice
      attr_reader :raw_data

      def initialize(data)
        @raw_data = data || {}
      end

      def ksef_number
        @raw_data['ksefNumber']
      end

      def invoice_number
        @raw_data['invoiceNumber']
      end

      def issue_date
        @raw_data['issueDate']
      end

      def invoicing_date
        @raw_data['invoicingDate']
      end

      def net_amount
        @raw_data['netAmount']
      end

      def gross_amount
        @raw_data['grossAmount']
      end

      def vat_amount
        @raw_data['vatAmount']
      end

      def currency
        @raw_data['currency']
      end

      def seller_name
        @raw_data.dig('seller', 'name')
      end

      def seller_nip
        @raw_data.dig('seller', 'nip')
      end

      def buyer_name
        @raw_data.dig('buyer', 'name')
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
