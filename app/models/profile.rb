# frozen_string_literal: true

class Profile
  include ActiveModel::Model

  attr_reader :id, :name, :nip, :token, :host

  class << self
    attr_writer :config_file

    def all
      config.profiles.map { |profile| build(profile) }
    end

    def find(id)
      profile = find_by(id: id.to_s)
      return profile if profile

      raise ActiveRecord::RecordNotFound, "Couldn't find Profile with 'id'=#{id}"
    end

    def find_by(filters = {})
      where(filters).first
    end

    def where(filters = {})
      criteria = filters.to_h.transform_keys(&:to_sym)
      return all if criteria.empty?

      all.select do |profile|
        criteria.all? do |attribute, expected|
          match_profile_attribute?(profile, attribute, expected)
        end
      end
    end

    def default
      default_name = config.default_profile_name
      return nil if default_name.to_s.strip.empty?

      find_by(name: default_name)
    end

    def default_host
      config.default_host
    end

    private

    def config
      Ksef::Config.new(@config_file)
    end

    def build(profile)
      new(
        id: profile.id,
        name: profile.name,
        nip: profile.nip,
        token: profile.token,
        host: profile.host
      )
    end

    def match_profile_attribute?(profile, attribute, expected)
      return false unless profile.respond_to?(attribute)

      actual = profile.public_send(attribute)
      expected.nil? ? actual.nil? : actual.to_s == expected.to_s
    end
  end

  def initialize(id:, name:, nip:, token:, host:)
    @id = id
    @name = name
    @nip = nip
    @token = token
    @host = host
  end

  def persisted?
    true
  end

  def readonly?
    true
  end

  def to_param
    id
  end

  def update!(*)
    raise ActiveRecord::ReadOnlyRecord, "Profile is read-only"
  end

  def destroy!
    raise ActiveRecord::ReadOnlyRecord, "Profile is read-only"
  end
end
