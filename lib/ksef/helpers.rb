# frozen_string_literal: true

module Ksef
  # Shared formatting helpers used by the app and views
  module Helpers
    def truncate(str, max_length)
      str.length > max_length ? "#{str[0, max_length - 2]}.." : str
    end

    def format_amount(amount, currency)
      return 'N/A' unless amount
      format('%.2f %s', amount, currency || 'PLN')
    end
  end
end
