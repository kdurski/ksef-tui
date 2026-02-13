# frozen_string_literal: true

require "test_helper"
class ProfileTest < ActiveSupport::TestCase
  def test_initializes_with_default_host
    profile = Ksef::Models::Profile.new(name: "Prod", nip: "123", token: "tok")

    assert_equal "api.ksef.mf.gov.pl", profile.host
    assert_equal "prod", profile.id
  end

  def test_to_s_returns_name
    profile = Ksef::Models::Profile.new(name: "Test", nip: "123", token: "tok", host: "ksef-test.mf.gov.pl", id: "test-main")

    assert_equal "Test", profile.to_s
    assert_equal "test-main", profile.id
  end
end
