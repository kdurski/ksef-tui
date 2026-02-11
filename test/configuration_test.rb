# frozen_string_literal: true

require_relative "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @config_path = File.join(Dir.tmpdir, "ksef_test_config.yml")
  end

  def teardown
    FileUtils.rm_f(@config_path)
  end

  def test_loads_profiles
    File.write(@config_path, <<~YAML)
      default: "Prod"
      profiles:
        - name: "Prod"
          nip: "111"
          token: "secret"
        - name: "Test"
          nip: "222"
          token: "test"
          host: "test.api"
    YAML

    config = Ksef::Configuration.new(@config_path)

    assert_equal 2, config.profiles.length
    assert_equal "Prod", config.default_profile_name

    prod = config.get_profile("Prod")
    assert_equal "111", prod.nip
    assert_equal "api.ksef.mf.gov.pl", prod.host # Default

    test_profile = config.get_profile("Test")
    assert_equal "222", test_profile.nip
    assert_equal "test.api", test_profile.host
  end

  def test_handles_missing_file
    FileUtils.rm_f(@config_path)
    config = Ksef::Configuration.new(@config_path)
    assert_empty config.profiles
  end

  def test_save_config
    config = Ksef::Configuration.new(@config_path)
    profiles = {
      "New" => {nip: "333", token: "new", host: "new.api"}
    }

    config.save(profiles, default: "New")

    saved_config = YAML.load_file(@config_path)
    assert_equal "New", saved_config["default"]
    assert_equal "333", saved_config["profiles"][0]["nip"]
  end
end
