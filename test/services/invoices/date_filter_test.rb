# frozen_string_literal: true

require "test_helper"

module Invoices
  class DateFilterTest < ActiveSupport::TestCase
    def test_defaults_to_last_30_days
      filter = DateFilter.new({}, today: Date.new(2026, 4, 18))

      assert_predicate filter, :valid?
      assert_equal Date.new(2026, 3, 19), filter.from_date
      assert_equal Date.new(2026, 4, 18), filter.to_date
      assert_equal "last_30_days", filter.active_range_key
      assert_equal "Showing invoices from the last 30 days", filter.summary
      assert_equal({}, filter.request_params)
    end

    def test_last_30_days_preset_resolves_expected_dates
      filter = DateFilter.new({ "range" => "last_30_days" }, today: Date.new(2026, 4, 18))

      assert_predicate filter, :valid?
      assert_equal Date.new(2026, 3, 19), filter.from_date
      assert_equal Date.new(2026, 4, 18), filter.to_date
      assert_equal({ range: "last_30_days" }, filter.request_params)
    end

    def test_this_month_preset_resolves_expected_dates
      filter = DateFilter.new({ "range" => "this_month" }, today: Date.new(2026, 4, 18))

      assert_predicate filter, :valid?
      assert_equal Date.new(2026, 4, 1), filter.from_date
      assert_equal Date.new(2026, 4, 18), filter.to_date
      assert_equal "this_month", filter.active_range_key
      assert_equal "Showing invoices from April 2026 to date", filter.summary
    end

    def test_last_month_preset_resolves_expected_dates
      filter = DateFilter.new({ "range" => "last_month" }, today: Date.new(2026, 4, 18))

      assert_predicate filter, :valid?
      assert_equal Date.new(2026, 3, 1), filter.from_date
      assert_equal Date.new(2026, 3, 31), filter.to_date
      assert_equal "last_month", filter.active_range_key
      assert_equal "Showing invoices from March 2026", filter.summary
    end

    def test_valid_manual_range_resolves_to_custom
      filter = DateFilter.new(
        { "range" => "custom", "from_date" => "2026-02-01", "to_date" => "2026-02-15" },
        today: Date.new(2026, 4, 18)
      )

      assert_predicate filter, :valid?
      assert_equal Date.new(2026, 2, 1), filter.from_date
      assert_equal Date.new(2026, 2, 15), filter.to_date
      assert_equal "custom", filter.active_range_key
      assert_equal "2026-02-01", filter.from_value
      assert_equal "2026-02-15", filter.to_value
      assert_equal(
        { range: "custom", from_date: "2026-02-01", to_date: "2026-02-15" },
        filter.request_params
      )
    end

    def test_invalid_manual_dates_return_error
      filter = DateFilter.new(
        { "range" => "custom", "from_date" => "2026-02-30", "to_date" => "2026-03-02" },
        today: Date.new(2026, 4, 18)
      )

      refute_predicate filter, :valid?
      assert_equal "Use valid calendar dates for both From and To.", filter.error
      assert_nil filter.from_date
      assert_nil filter.to_date
      assert_equal "custom", filter.active_range_key
    end

    def test_from_date_after_to_date_is_invalid
      filter = DateFilter.new(
        { "range" => "custom", "from_date" => "2026-04-19", "to_date" => "2026-04-18" },
        today: Date.new(2026, 4, 18)
      )

      refute_predicate filter, :valid?
      assert_equal "The From date cannot be later than the To date.", filter.error
    end

    def test_query_params_match_ksef_date_range_payload
      filter = DateFilter.new({ "range" => "last_month" }, today: Date.new(2026, 4, 18))

      assert_equal(
        {
          subjectType: Ksef::Client::SUBJECT_TYPES[:buyer],
          dateRange: {
            dateType: "PermanentStorage",
            from: Date.new(2026, 3, 1).beginning_of_day.iso8601,
            to: Date.new(2026, 3, 31).end_of_day.iso8601
          }
        },
        filter.query_params
      )
    end

    def test_range_options_include_dynamic_month_labels
      filter = DateFilter.new({}, today: Date.new(2026, 4, 18))

      assert_equal(
        [
          { key: "last_30_days", label: "Last 30 days" },
          { key: "this_month", label: "This month (April 2026)" },
          { key: "last_month", label: "Last month (March 2026)" }
        ],
        filter.range_options
      )
    end

    def test_january_rollover_uses_previous_year_for_last_month_label
      filter = DateFilter.new({}, today: Date.new(2026, 1, 10))

      assert_equal "Last month (December 2025)", filter.range_options.last[:label]
    end
  end
end
