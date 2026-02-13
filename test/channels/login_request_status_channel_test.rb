# frozen_string_literal: true

require "test_helper"

class LoginRequestStatusChannelTest < ActionCable::Channel::TestCase
  def setup
    super
    @login_request = KsefLoginRequest.create!(
      nip: "1111111111",
      seed_token: "seed-token",
      host: "api.example"
    )
  end

  def test_subscribes_for_matching_pending_login_request
    stub_connection(pending_login_request_id: @login_request.id)

    subscribe(login_request_id: @login_request.id)

    assert subscription.confirmed?
    assert_has_stream_for @login_request
  end

  def test_rejects_for_other_login_request
    stub_connection(pending_login_request_id: @login_request.id + 1)

    subscribe(login_request_id: @login_request.id)

    assert subscription.rejected?
  end
end
