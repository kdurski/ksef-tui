# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../lib/ksef/tui/input_handler'

# Minimal mock TUI for testing input handler
class MockTui
  attr_accessor :events

  def initialize
    @events = []
  end

  def poll_event
    @events.shift || { type: :none }
  end
end

# Test class that includes InputHandler
class InputHandlerTestClass
  include Ksef::Tui::InputHandler

  attr_accessor :invoices, :selected_index, :show_detail, :status, :tui

  def initialize
    @invoices = []
    @selected_index = 0
    @show_detail = false
    @status = :disconnected
    @tui = MockTui.new
  end

  # Stub methods called by input handler
  def connect; end
  def refresh; end
end

class InputHandlerTest < Minitest::Test
  def setup
    @handler = InputHandlerTestClass.new
  end

  def test_quit_with_q_from_list_view
    @handler.tui.events = [{ type: :key, code: 'q' }]
    result = @handler.handle_input
    assert_equal :quit, result
  end

  def test_quit_with_ctrl_c
    @handler.tui.events = [{ type: :key, code: 'c', modifiers: ['ctrl'] }]
    result = @handler.handle_input
    assert_equal :quit, result
  end

  def test_q_goes_back_from_detail_view
    @handler.show_detail = true
    @handler.tui.events = [{ type: :key, code: 'q' }]
    
    result = @handler.handle_input
    assert_nil result
    refute @handler.show_detail
  end

  def test_escape_closes_detail_view
    @handler.show_detail = true
    @handler.tui.events = [{ type: :key, code: 'esc' }]
    
    @handler.handle_input
    refute @handler.show_detail
  end

  def test_b_closes_detail_view
    @handler.show_detail = true
    @handler.tui.events = [{ type: :key, code: 'b' }]
    
    @handler.handle_input
    refute @handler.show_detail
  end

  def test_enter_opens_detail_when_invoices_exist
    @handler.invoices = [{ 'id' => '1' }]
    @handler.tui.events = [{ type: :key, code: 'enter' }]
    
    @handler.handle_input
    assert @handler.show_detail
  end

  def test_enter_does_nothing_when_no_invoices
    @handler.invoices = []
    @handler.tui.events = [{ type: :key, code: 'enter' }]
    
    @handler.handle_input
    refute @handler.show_detail
  end

  def test_navigate_down
    @handler.invoices = [{ 'id' => '1' }, { 'id' => '2' }, { 'id' => '3' }]
    @handler.selected_index = 0
    @handler.tui.events = [{ type: :key, code: 'down' }]
    
    @handler.handle_input
    assert_equal 1, @handler.selected_index
  end

  def test_navigate_down_wraps_around
    @handler.invoices = [{ 'id' => '1' }, { 'id' => '2' }]
    @handler.selected_index = 1
    @handler.tui.events = [{ type: :key, code: 'down' }]
    
    @handler.handle_input
    assert_equal 0, @handler.selected_index
  end

  def test_navigate_up
    @handler.invoices = [{ 'id' => '1' }, { 'id' => '2' }]
    @handler.selected_index = 1
    @handler.tui.events = [{ type: :key, code: 'up' }]
    
    @handler.handle_input
    assert_equal 0, @handler.selected_index
  end

  def test_navigate_up_wraps_around
    @handler.invoices = [{ 'id' => '1' }, { 'id' => '2' }]
    @handler.selected_index = 0
    @handler.tui.events = [{ type: :key, code: 'up' }]
    
    @handler.handle_input
    assert_equal 1, @handler.selected_index
  end

  def test_j_navigates_down
    @handler.invoices = [{ 'id' => '1' }, { 'id' => '2' }]
    @handler.selected_index = 0
    @handler.tui.events = [{ type: :key, code: 'j' }]
    
    @handler.handle_input
    assert_equal 1, @handler.selected_index
  end

  def test_k_navigates_up
    @handler.invoices = [{ 'id' => '1' }, { 'id' => '2' }]
    @handler.selected_index = 1
    @handler.tui.events = [{ type: :key, code: 'k' }]
    
    @handler.handle_input
    assert_equal 0, @handler.selected_index
  end

  def test_unknown_key_returns_nil
    @handler.tui.events = [{ type: :key, code: 'x' }]
    result = @handler.handle_input
    assert_nil result
  end
end
