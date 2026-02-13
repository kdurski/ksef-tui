# frozen_string_literal: true

require "test_helper"
class InvoiceFindAllServiceTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :last_path, :last_body

    def initialize(response)
      @response = response
    end

    def post(path, body)
      @last_path = path
      @last_body = body
      @response
    end
  end

  def setup
    # Defines Ksef::InvoiceError used by service classes.
    Ksef::Models::Invoice
  end

  def test_call_returns_normalized_invoices
    client = FakeClient.new(
      {
        "invoices" => [
          {
            ksefNumber: "KSEF-1",
            seller: { nip: "1234567890" },
            tags: [ { code: 1 } ]
          }
        ]
      }
    )
    query = { subjectType: "Subject2" }

    result = Ksef::Services::InvoiceFindAllService.new(client: client, query_body: query).call

    assert_equal "/invoices/query/metadata", client.last_path
    assert_equal query, client.last_body
    assert_equal(
      [
        {
          "ksefNumber" => "KSEF-1",
          "seller" => { "nip" => "1234567890" },
          "tags" => [ { "code" => 1 } ]
        }
      ],
      result
    )
  end

  def test_call_raises_when_query_body_is_not_hash
    client = FakeClient.new({})
    service = Ksef::Services::InvoiceFindAllService.new(client: client, query_body: "bad")

    assert_raises(Ksef::InvoiceError) { service.call }
  end

  def test_call_raises_when_response_has_error
    client = FakeClient.new({ "error" => "boom" })
    service = Ksef::Services::InvoiceFindAllService.new(client: client, query_body: {})

    error = assert_raises(Ksef::InvoiceError) { service.call }
    assert_match(/boom/, error.message)
  end

  def test_call_raises_on_invalid_invoice_entry
    client = FakeClient.new({ "invoices" => [ "not-a-hash" ] })
    service = Ksef::Services::InvoiceFindAllService.new(client: client, query_body: {})

    assert_raises(Ksef::InvoiceError) { service.call }
  end
end
