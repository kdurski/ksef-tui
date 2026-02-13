# frozen_string_literal: true

require "test_helper"
class SessionTest < ActiveSupport::TestCase
  def test_active_session
    future = (Time.now + 3600).iso8601
    session = Ksef::Session.new(access_token: "token", access_token_valid_until: future)
    assert session.active?
    refute session.expired?
  end

  def test_expired_session
    past = (Time.now - 3600).iso8601
    session = Ksef::Session.new(access_token: "token", access_token_valid_until: past)
    refute session.active?
    assert session.expired?
  end

  def test_nil_token_not_active
    future = (Time.now + 3600).iso8601
    session = Ksef::Session.new(access_token: nil, access_token_valid_until: future)
    refute session.active?
  end

  def test_invalid_date_not_expired
    session = Ksef::Session.new(access_token: "token", access_token_valid_until: "invalid-date")
    # If date is invalid, expired? returns false (as per implementation rescue)
    refute session.expired?
    assert session.active?
  end

  def test_nil_date_not_expired
    session = Ksef::Session.new(access_token: "token", access_token_valid_until: nil)
    refute session.expired?
    assert session.active?
  end
end
