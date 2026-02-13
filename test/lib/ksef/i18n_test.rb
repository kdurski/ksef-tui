# frozen_string_literal: true

require "test_helper"
require "ksef/i18n"

class I18nTest < ActiveSupport::TestCase
  def setup
    # Reset I18n state before each test
    Ksef::I18n.setup(locale: :pl)
  end

  def test_setup_loads_translations
    assert_equal :pl, Ksef::I18n.locale
    # Should have loaded keys from pl.yml
    assert_equal "Aplikacja uruchomiona", Ksef::I18n.t("app.started")
  end

  def test_locale_switching
    Ksef::I18n.locale = :en
    assert_equal :en, Ksef::I18n.locale
    assert_equal "Application started", Ksef::I18n.t("app.started")

    Ksef::I18n.locale = :pl
    assert_equal :pl, Ksef::I18n.locale
    assert_equal "Aplikacja uruchomiona", Ksef::I18n.t("app.started")
  end

  def test_toggle_locale
    Ksef::I18n.setup(locale: :pl)

    # Toggle pl -> en
    new_locale = Ksef::I18n.toggle_locale
    assert_equal :en, new_locale
    assert_equal :en, Ksef::I18n.locale

    # Toggle en -> pl
    new_locale = Ksef::I18n.toggle_locale
    assert_equal :pl, new_locale
    assert_equal :pl, Ksef::I18n.locale
  end

  def test_t_with_nested_keys
    assert_equal "Numer KSeF", Ksef::I18n.t("views.main.headers.ksef_number")
  end

  def test_t_with_interpolation
    # fetched: "Pobrano %{count} faktur(y)"
    message = Ksef::I18n.t("app.fetched", count: 5)
    assert_equal "Pobrano 5 faktur(y)", message
  end

  def test_missing_key
    # I18n gem raises MissingTranslationData by default in tests context usually,
    # or returns "translation missing: ..." string depending on config.
    # In minitest environment without rails, it usually raises.
    # Let's check what it does.

    assert_includes Ksef::I18n.t("non.existent.key"), "Translation missing"
  end
end
