# frozen_string_literal: true

require_relative "../test_helper"

class ProfileModelTest < ActiveSupport::TestCase
  def setup
    @config_path = File.join(Dir.tmpdir, "profile_model_test_#{Process.pid}_#{object_id}.yml")
    File.write(@config_path, <<~YAML)
      settings:
        default_host: "api.default.example"
      default_profile: "Prod"
      profiles:
        - name: "Prod"
          id: "Prod"
          nip: "1111111111"
          token: "prod-token"
          host: "prod.example"
        - name: "HENTO (testowe)"
          nip: "2222222222"
          token: "test-token"
    YAML
    Profile.config_file = @config_path
  end

  def teardown
    FileUtils.rm_f(@config_path)
    Profile.config_file = nil
  end

  def test_all_returns_profiles
    profiles = Profile.all

    assert_equal 2, profiles.length
    assert_equal [ "HENTO (testowe)", "Prod" ], profiles.map(&:name).sort
    assert profiles.all?(&:persisted?)
    assert profiles.all?(&:readonly?)
  end

  def test_find_by_name
    profile = Profile.find_by(name: "Prod")

    assert_equal "Prod", profile.name
    assert_equal "prod.example", profile.host
  end

  def test_find_by_id_maps_to_name
    profile = Profile.find_by(id: "Prod")

    assert_equal "Prod", profile.name
  end

  def test_find_by_id
    profile = Profile.find("hento-testowe")

    assert_equal "hento-testowe", profile.id
    assert_equal "2222222222", profile.nip
  end

  def test_find_raises_for_missing_record
    error = assert_raises(ActiveRecord::RecordNotFound) { Profile.find("Missing") }
    assert_match(/Couldn't find Profile/, error.message)
  end

  def test_where_filters_profiles
    result = Profile.where(nip: "1111111111")

    assert_equal 1, result.length
    assert_equal "Prod", result.first.name
  end

  def test_default_returns_default_profile
    assert_equal "Prod", Profile.default&.name
  end

  def test_default_host_comes_from_settings
    assert_equal "api.default.example", Profile.default_host
  end

  def test_update_and_destroy_raise_read_only
    profile = Profile.find("Prod")

    assert_raises(ActiveRecord::ReadOnlyRecord) { profile.update!(name: "Other") }
    assert_raises(ActiveRecord::ReadOnlyRecord) { profile.destroy! }
  end
end
