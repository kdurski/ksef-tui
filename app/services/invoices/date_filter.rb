module Invoices
  class DateFilter
    CUSTOM_RANGE = "custom"
    DEFAULT_RANGE = "this_month"
    PRESET_RANGES = %w[last_30_days this_month last_month].freeze

    attr_reader :error, :from_date, :to_date, :active_range_key, :from_value, :to_value, :summary

    def initialize(params, today: Date.current)
      @params = normalize_params(params)
      @today = today
      resolve_state
    end

    def valid?
      error.nil?
    end

    def request_params
      @request_params.dup
    end

    def range_options
      [
        { key: "last_month", label: "Last month (#{month_label_for(today.last_month)})" },
        { key: "last_30_days", label: "Last 30 days" },
        { key: "this_month", label: "This month (#{month_label_for(today)})" }
      ]
    end

    def trigger_label
      return "Custom range" if error.present?

      case active_range_key
      when "last_30_days"
        "Last 30 days"
      when "this_month"
        "#{month_label_for(from_date)} to date"
      when "last_month"
        month_label_for(from_date)
      when CUSTOM_RANGE
        compact_custom_range_label
      else
        "Date range"
      end
    end

    def query_params
      return nil unless valid?

      {
        subjectType: Ksef::Client::SUBJECT_TYPES[:buyer],
        dateRange: {
          dateType: "PermanentStorage",
          from: from_date.beginning_of_day.iso8601,
          to: to_date.end_of_day.iso8601
        }
      }
    end

    private

    attr_reader :params, :today

    def normalize_params(raw_params)
      params_hash =
        if raw_params.respond_to?(:to_unsafe_h)
          raw_params.to_unsafe_h
        elsif raw_params.respond_to?(:to_h)
          raw_params.to_h
        else
          raw_params
        end

      params_hash.to_h.transform_keys(&:to_s)
    end

    def resolve_state
      selected_range = params["range"].presence
      from_input = params["from_date"].to_s
      to_input = params["to_date"].to_s

      if PRESET_RANGES.include?(selected_range)
        resolve_preset_state(selected_range)
      elsif selected_range == CUSTOM_RANGE || from_input.present? || to_input.present?
        resolve_custom_state(from_input, to_input)
      else
        resolve_default_state
      end
    end

    def resolve_preset_state(range_key)
      preset_from_date, preset_to_date = preset_dates_for(range_key)

      set_valid_state(
        from_date: preset_from_date,
        to_date: preset_to_date,
        active_range_key: range_key,
        summary: filter_summary_for(range_key, preset_from_date),
        request_params: { range: range_key }
      )
    end

    def resolve_custom_state(from_input, to_input)
      parsed_from_date = parse_filter_date(from_input)
      parsed_to_date = parse_filter_date(to_input)
      validation_error = validate_manual_date_range(
        from_input: from_input,
        to_input: to_input,
        from_date: parsed_from_date,
        to_date: parsed_to_date
      )

      if validation_error
        set_invalid_state(validation_error, from_input, to_input)
        return
      end

      set_valid_state(
        from_date: parsed_from_date,
        to_date: parsed_to_date,
        active_range_key: CUSTOM_RANGE,
        summary: "Showing invoices from #{parsed_from_date.iso8601} to #{parsed_to_date.iso8601}",
        request_params: {
          range: CUSTOM_RANGE,
          from_date: parsed_from_date.iso8601,
          to_date: parsed_to_date.iso8601
        }
      )
    end

    def resolve_default_state
      default_from_date, default_to_date = preset_dates_for(DEFAULT_RANGE)

      set_valid_state(
        from_date: default_from_date,
        to_date: default_to_date,
        active_range_key: DEFAULT_RANGE,
        summary: filter_summary_for(DEFAULT_RANGE, default_from_date),
        request_params: {}
      )
    end

    def set_valid_state(from_date:, to_date:, active_range_key:, summary:, request_params:)
      @error = nil
      @from_date = from_date
      @to_date = to_date
      @from_value = from_date.iso8601
      @to_value = to_date.iso8601
      @active_range_key = active_range_key
      @summary = summary
      @request_params = request_params
    end

    def set_invalid_state(validation_error, from_input, to_input)
      @error = validation_error
      @from_date = nil
      @to_date = nil
      @from_value = from_input
      @to_value = to_input
      @active_range_key = CUSTOM_RANGE
      @summary = "Choose a valid date range to load invoices."
      @request_params = {
        range: CUSTOM_RANGE,
        from_date: from_input.presence,
        to_date: to_input.presence
      }.compact
    end

    def preset_dates_for(range_key)
      case range_key
      when "last_30_days"
        [ today - 30.days, today ]
      when "this_month"
        [ today.beginning_of_month, today ]
      when "last_month"
        last_month = today.last_month
        [ last_month.beginning_of_month, last_month.end_of_month ]
      else
        raise ArgumentError, "Unsupported invoice range: #{range_key}"
      end
    end

    def month_label_for(date)
      date.strftime("%B %Y")
    end

    def compact_custom_range_label
      if from_date.year == to_date.year
        "#{from_date.strftime('%b %-d')} - #{to_date.strftime('%b %-d, %Y')}"
      else
        "#{from_date.strftime('%b %-d, %Y')} - #{to_date.strftime('%b %-d, %Y')}"
      end
    end

    def filter_summary_for(range_key, from_date)
      case range_key
      when "last_30_days"
        "Showing invoices from the last 30 days"
      when "this_month"
        "Showing invoices from #{month_label_for(from_date)} to date"
      when "last_month"
        "Showing invoices from #{month_label_for(from_date)}"
      else
        "Showing invoices from #{from_date.iso8601}"
      end
    end

    def parse_filter_date(value)
      return nil if value.blank?

      Date.iso8601(value)
    rescue ArgumentError
      nil
    end

    def validate_manual_date_range(from_input:, to_input:, from_date:, to_date:)
      return "Select both a From date and a To date." if from_input.blank? || to_input.blank?
      return "Use valid calendar dates for both From and To." if from_date.nil? || to_date.nil?
      return "The From date cannot be later than the To date." if from_date > to_date

      nil
    end
  end
end
