# frozen_string_literal: true

require "test_helper"
class CurrentTest < ActiveSupport::TestCase
  def setup
    Ksef::Current.reset
  end

  def teardown
    Ksef::Current.reset
  end

  def test_with_client_sets_and_restores_client
    client = Object.new

    Ksef::Current.with_client(client) do
      assert_equal client, Ksef::Current.client
    end

    assert_nil Ksef::Current.client
  end

  def test_with_context_sets_context_and_derived_client
    context_client = Object.new
    context = Ksef::Context.new(client: context_client)

    Ksef::Current.with_context(context) do
      assert_equal context, Ksef::Current.context
      assert_equal context_client, Ksef::Current.client
    end

    assert_nil Ksef::Current.context
    assert_nil Ksef::Current.client
  end
end
