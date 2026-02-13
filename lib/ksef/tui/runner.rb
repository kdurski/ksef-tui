# frozen_string_literal: true

require "optparse"
require_relative "app"

module Ksef
  module Tui
    module Runner
      module_function

      def run(argv = ARGV)
        options = {}

        OptionParser.new do |opts|
          opts.on("-p", "--profile PROFILE", "Select profile to use") do |profile|
            options[:profile] = profile
          end
        end.parse!(argv.dup)

        App.new(options[:profile]).run
      end
    end
  end
end
