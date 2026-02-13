# frozen_string_literal: true

require "test_helper"
class InvoiceFindServiceTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :last_path

    def initialize(response)
      @response = response
    end

    def get_xml(path)
      @last_path = path
      @response
    end
  end

  def setup
    # Defines Ksef::InvoiceError used by service classes.
    Ksef::Models::Invoice
  end

  def test_call_escapes_ksef_number_and_maps_xml
    client = FakeClient.new("<Invoice/>")
    mapper = Minitest::Mock.new
    mapper.expect(:call, { "invoiceNumber" => "FV/1" }, [ "<Invoice/>" ])

    service = Ksef::Services::InvoiceFindService.new(
      client: client,
      ksef_number: "ABC/ 1",
      mapper: mapper
    )
    result = service.call

    assert_equal "/invoices/ksef/ABC%2F+1", client.last_path
    assert_equal({ "invoiceNumber" => "FV/1" }, result)
    mapper.verify
  end

  def test_call_raises_when_ksef_number_missing
    service = Ksef::Services::InvoiceFindService.new(client: FakeClient.new("xml"), ksef_number: "  ")

    assert_raises(Ksef::InvoiceError) { service.call }
  end

  def test_call_raises_when_client_returns_error_hash
    service = Ksef::Services::InvoiceFindService.new(
      client: FakeClient.new({ "error" => "not found" }),
      ksef_number: "ABC"
    )

    error = assert_raises(Ksef::InvoiceError) { service.call }
    assert_match(/not found/, error.message)
  end

  def test_call_raises_when_response_is_not_xml_string
    service = Ksef::Services::InvoiceFindService.new(
      client: FakeClient.new([ "unexpected" ]),
      ksef_number: "ABC"
    )

    assert_raises(Ksef::InvoiceError) { service.call }
  end
end
