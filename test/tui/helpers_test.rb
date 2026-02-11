# frozen_string_literal: true

require_relative "../test_helper"

require_relative "../../lib/ksef/tui/helpers"

# Test helper methods from the app
class HelpersTest < Minitest::Test
  include Ksef::Tui::Helpers

  # truncate tests
  def test_truncate_short_string
    assert_equal "hello", truncate("hello", 10)
  end

  def test_truncate_exact_length
    assert_equal "1234567890", truncate("1234567890", 10)
  end

  def test_truncate_long_string
    assert_equal "12345678..", truncate("1234567890123", 10)
  end

  def test_truncate_empty_string
    assert_equal "", truncate("", 10)
  end

  def test_truncate_single_char
    assert_equal "a", truncate("a", 10)
  end

  # format_amount tests
  def test_format_amount_with_pln
    assert_equal "100.00 PLN", format_amount(100, "PLN")
  end

  def test_format_amount_with_eur
    assert_equal "99.99 EUR", format_amount(99.99, "EUR")
  end

  def test_format_amount_nil_currency_defaults_to_pln
    assert_equal "50.00 PLN", format_amount(50, nil)
  end

  def test_format_amount_nil_returns_na
    assert_equal "N/A", format_amount(nil, "PLN")
  end

  def test_format_amount_zero
    assert_equal "0.00 PLN", format_amount(0, "PLN")
  end

  def test_format_amount_decimal_precision
    assert_equal "123.46 PLN", format_amount(123.456, "PLN")
  end

  def test_format_amount_large_number
    assert_equal "1000000.00 PLN", format_amount(1_000_000, "PLN")
  end
end
