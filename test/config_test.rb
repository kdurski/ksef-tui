# frozen_string_literal: true

require_relative "test_helper"

class ConfigTest < Minitest::Test
  def setup
    @config_path = File.join(Dir.tmpdir, "ksef_test_config.yml")
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
end
