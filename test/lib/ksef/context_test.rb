# frozen_string_literal: true

require "test_helper"
class ContextTest < ActiveSupport::TestCase
  def test_initializes_with_all_fields
    context = Ksef::Context.new(
      config: :cfg,
      client: :client,
      profile_name: "Test",
      host: "ksef-test.mf.gov.pl"
    )

    assert_equal :cfg, context.config
    assert_equal :client, context.client
    assert_equal "Test", context.profile_name
    assert_equal "ksef-test.mf.gov.pl", context.host
  end

  def test_with_returns_new_context_with_overrides
    context = Ksef::Context.new(config: :cfg1, client: :client1, profile_name: "A", host: "h1")

    updated = context.with(client: :client2, host: "h2")

    refute_equal context.object_id, updated.object_id
    assert_equal :cfg1, updated.config
    assert_equal :client2, updated.client
    assert_equal "A", updated.profile_name
    assert_equal "h2", updated.host
  end
end
