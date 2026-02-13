# frozen_string_literal: true

require "cgi"



module Ksef
  module Services
    class InvoiceFindService
      def initialize(client:, ksef_number:, mapper: nil)
        @client = client
        @ksef_number = ksef_number
        @mapper = mapper || InvoiceXmlMapper.new(ksef_number: ksef_number)
      end

      def call
        raise Ksef::InvoiceError, "ksef_number is required" if @ksef_number.to_s.strip.empty?

        response = @client.get_xml("/invoices/ksef/#{CGI.escape(@ksef_number.to_s)}")
        raise Ksef::InvoiceError, response["error"] if response.is_a?(Hash) && response["error"]
        raise Ksef::InvoiceError, "Invalid XML invoice response" unless response.is_a?(String)

        @mapper.call(response)
      end
    end
  end
end
