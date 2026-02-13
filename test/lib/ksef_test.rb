# frozen_string_literal: true

require "test_helper"
class KsefTest < ActiveSupport::TestCase
  def setup
    @original_default_config = Ksef::Config.default
    @original_context = Ksef.context
    @original_client = Ksef.current_client
    Ksef.context = nil
    Ksef.current_client = nil
  end

  def teardown
    Ksef.context = @original_context
    Ksef.current_client = @original_client
    Ksef::Config.default = @original_default_config
  end

  def test_config_prefers_context_config
    global_config = Ksef::Config.new(temp_config_path("global"))
    context_config = Ksef::Config.new(temp_config_path("context"))

    Ksef.config = global_config
    Ksef.with_context(Ksef::Context.new(config: context_config)) do
      assert_equal context_config, Ksef.config
    end

    assert_equal global_config, Ksef.config
  end

  def test_config_writer_updates_context_only_inside_context
    global_config = Ksef::Config.new(temp_config_path("global_writer"))
    context_config = Ksef::Config.new(temp_config_path("context_writer"))
    replacement = Ksef::Config.new(temp_config_path("replacement"))

    Ksef.config = global_config
    Ksef.with_context(Ksef::Context.new(config: context_config)) do
      Ksef.config = replacement
      assert_equal replacement, Ksef.config
    end

    assert_equal global_config, Ksef.config
  end

  def test_current_client_prefers_context_client
    global_client = Object.new
    context_client = Object.new
    Ksef.current_client = global_client

    Ksef.with_context(Ksef::Context.new(client: context_client)) do
      assert_equal context_client, Ksef.current_client
    end

    assert_equal global_client, Ksef.current_client
  end

  def test_current_client_writer_updates_context_client
    replacement_client = Object.new
    Ksef.with_context(Ksef::Context.new(client: Object.new)) do
      Ksef.current_client = replacement_client
      assert_equal replacement_client, Ksef.current_client
      assert_equal replacement_client, Ksef.context.client
    end
  end

  def test_context_writer_syncs_current_client
    context_client = Object.new
    context = Ksef::Context.new(client: context_client)

    Ksef.context = context

    assert_equal context, Ksef.context
    assert_equal context_client, Ksef.current_client
  end

  private

  def temp_config_path(name)
    File.join(Dir.tmpdir, "ksef_test_#{name}_#{Process.pid}_#{object_id}.yml")
  end
end
