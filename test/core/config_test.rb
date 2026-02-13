# frozen_string_literal: true

require_relative "../test_helper"

class ConfigTest < ActiveSupport::TestCase
  def setup
    @config_path = File.join(Dir.tmpdir, "ksef_test_config_#{Process.pid}_#{object_id}.yml")
  end

  def teardown
    FileUtils.rm_f(@config_path)
  end

  def test_loads_profiles_and_settings
    File.write(@config_path, <<~YAML)
      settings:
        locale: "en"
        default_host: "api.default.example"
        max_retries: 7
        open_timeout: 11
        read_timeout: 22
        write_timeout: 33
      default_profile: "Prod"
      profiles:
        - name: "Prod"
          nip: "111"
          token: "secret"
        - name: "Test"
          nip: "222"
          token: "test"
          host: "test.api"
    YAML

    config = Ksef::Config.new(@config_path)

    assert_equal 2, config.profiles.length
    assert_equal "Prod", config.default_profile_name
    assert_equal "Prod", config.current_profile_name
    assert_equal :en, config.locale
    assert_equal "api.default.example", config.default_host
    assert_equal 7, config.max_retries
    assert_equal 11, config.open_timeout
    assert_equal 22, config.read_timeout
    assert_equal 33, config.write_timeout

    prod = config.get_profile("Prod")
    assert_equal "111", prod.nip
    assert_equal "api.default.example", prod.host # Host from generic defaults

    test_profile = config.get_profile("Test")
    assert_equal "222", test_profile.nip
    assert_equal "test.api", test_profile.host
  end

  def test_handles_missing_file
    FileUtils.rm_f(@config_path)
    config = Ksef::Config.new(@config_path)
    assert_empty config.profiles
    assert_equal :pl, config.locale
    assert_equal "api.ksef.mf.gov.pl", config.default_host
    assert_equal 3, config.max_retries
  end

  def test_save_config
    config = Ksef::Config.new(@config_path)
    config.locale = :en
    config.max_retries = 4
    config.open_timeout = 8
    config.read_timeout = 16
    config.write_timeout = 32
    config.default_host = "default.api"
    profiles = {"New" => {nip: "333", token: "new", host: "new.api"}}

    config.save(profiles, default: "New")

    saved_config = YAML.safe_load_file(@config_path)
    assert_equal "New", saved_config["default_profile"]
    assert_equal "New", saved_config["current_profile"]
    assert_equal "en", saved_config.dig("settings", "locale")
    assert_equal 4, saved_config.dig("settings", "max_retries")
    assert_equal "default.api", saved_config.dig("settings", "default_host")
    assert_equal "333", saved_config["profiles"][0]["nip"]
  end

  def test_select_profile_sets_current_profile
    File.write(@config_path, <<~YAML)
      default_profile: "Prod"
      profiles:
        - name: "Prod"
          nip: "111"
          token: "secret"
        - name: "Test"
          nip: "222"
          token: "test"
    YAML

    config = Ksef::Config.new(@config_path)
    selected = config.select_profile("Test")

    assert_equal "Test", selected.name
    assert_equal "Test", config.current_profile_name
    assert_equal "Test", config.current_profile.name
  end

  def test_select_profile_returns_nil_for_missing_name
    File.write(@config_path, <<~YAML)
      default_profile: "Prod"
      profiles:
        - name: "Prod"
          nip: "111"
          token: "secret"
    YAML

    config = Ksef::Config.new(@config_path)
    original = config.current_profile_name

    assert_nil config.select_profile("Missing")
    assert_equal original, config.current_profile_name
  end

  def test_load_ignores_malformed_profiles_and_falls_back_on_invalid_integers
    File.write(@config_path, <<~YAML)
      settings:
        max_retries: "bad"
        open_timeout: "oops"
        read_timeout: null
        write_timeout: "zzz"
      profiles:
        - "not-a-hash"
        - nip: "111"
          token: "missing-name"
        - name: "Valid"
          nip: "222"
          token: "ok"
    YAML

    config = Ksef::Config.new(@config_path)

    assert_equal 1, config.profiles.length
    assert_equal "Valid", config.current_profile_name
    assert_equal 3, config.max_retries
    assert_equal 10, config.open_timeout
    assert_equal 15, config.read_timeout
    assert_equal 10, config.write_timeout
  end

  def test_network_settings_returns_current_values
    config = Ksef::Config.new(@config_path)
    config.max_retries = 9
    config.open_timeout = 1
    config.read_timeout = 2
    config.write_timeout = 3

    assert_equal(
      {max_retries: 9, open_timeout: 1, read_timeout: 2, write_timeout: 3},
      config.network_settings
    )
  end

  def test_configure_sets_global_config
    original = Ksef.config

    configured = Ksef.configure(config_file: @config_path) do |cfg|
      cfg.locale = :en
      cfg.max_retries = 0
    end

    assert_equal configured, Ksef.config
    assert_equal :en, Ksef.config.locale
    assert_equal 0, Ksef.config.max_retries
  ensure
    Ksef.config = original
  end
end
