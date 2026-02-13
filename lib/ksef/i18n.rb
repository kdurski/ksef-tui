# frozen_string_literal: true

require "i18n"

module Ksef
  module I18n
    def self.setup(locale: :pl)
      ::I18n.load_path += Dir[File.expand_path("../../../config/locales/*.yml", __dir__)]
      ::I18n.default_locale = :pl
      ::I18n.locale = locale
      ::I18n.backend.load_translations
    end

    def self.locale
      ::I18n.locale
    end

    def self.locale=(loc)
      ::I18n.locale = loc
    end

    def self.toggle_locale
      locales = [ :pl, :en ]
      current_index = locales.index(::I18n.locale) || 0
      new_locale = locales[(current_index + 1) % locales.length]
      ::I18n.locale = new_locale
      new_locale
    end

    def self.t(...)
      ::I18n.t(...)
    end
  end
end
