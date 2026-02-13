ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"
require "minitest/mock"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    
    # Mock for TUI tests
    def with_test_terminal
      yield
    end

    def inject_key(key)
      event = case key
      when :ctrl_c
        {type: :key, code: "c", modifiers: ["ctrl"]}
      when String
        {type: :key, code: key}
      when Hash
        key
      else
        {type: :key, code: key.to_s}
      end
      @injected_keys ||= []
      @injected_keys << event
    end

    # Reset injected keys
    def setup
      super
      @injected_keys = []
    end
  end
end

# Stub Rect for Views
class StubRect
  attr_accessor :x, :y, :width, :height
  def initialize(x: 0, y: 0, width: 80, height: 24)
    @x, @y, @width, @height = x, y, width, height
  end
  def left; x; end
  def top; y; end
  def right; x + width; end
  def bottom; y + height; end
end

# Mock RatatuiRuby
if defined?(RatatuiRuby)
  module RatatuiRuby
    class << self
      attr_accessor :current_test_instance

      def run
        yield TUI.new
      end

      def poll_event
        if current_test_instance
          key = current_test_instance.instance_variable_get(:@injected_keys)&.shift
          return key if key
        end
        # Default fallback or loop breaker
        :quit
      end
    end

    class TUI
      def draw
        # yield a mock frame
        yield Frame.new
      end
      def poll_event
        RatatuiRuby.poll_event
      end
    end

    class Frame
      attr_reader :area
      def initialize
        @area = StubRect.new
      end
      def render_widget(widget, area); end
    end
  end
else
  # Define it if it doesn't exist (e.g. if gem is missing or not required yet, though it should be)
  module RatatuiRuby
    class << self
      attr_accessor :current_test_instance
      def run; yield TUI.new; end
      def poll_event
        if current_test_instance
          key = current_test_instance.instance_variable_get(:@injected_keys)&.shift
          return key if key
        end
        :quit
      end
    end
    class TUI
      def draw; yield Frame.new; end
      def poll_event; RatatuiRuby.poll_event; end
    end
    class Frame
      attr_reader :area
      def initialize; @area = StubRect.new; end
      def render_widget(widget, area); end
    end
  end
end

# Update TestCase to set current_test_instance
module ActiveSupport
  class TestCase
    setup do
      RatatuiRuby.current_test_instance = self
    end
  end
end
