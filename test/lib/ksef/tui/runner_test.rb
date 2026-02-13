# frozen_string_literal: true

require "test_helper"
class RunnerTest < ActiveSupport::TestCase
  def test_run_passes_profile_from_option
    app = Minitest::Mock.new
    app.expect(:run, nil)
    captured_profile = nil

    Ksef::Tui::App.stub(:new, ->(profile) {
      captured_profile = profile
      app
    }) do
      Ksef::Tui::Runner.run([ "--profile", "hento-test" ])
    end

    assert_equal "hento-test", captured_profile
    app.verify
  end

  def test_run_uses_nil_profile_when_not_passed
    app = Minitest::Mock.new
    app.expect(:run, nil)
    captured_profile = :unset

    Ksef::Tui::App.stub(:new, ->(profile) {
      captured_profile = profile
      app
    }) do
      Ksef::Tui::Runner.run([])
    end

    assert_nil captured_profile
    app.verify
  end
end
