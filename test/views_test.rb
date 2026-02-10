# frozen_string_literal: true

require_relative 'test_helper'

class ViewsTest < Minitest::Test
  include RatatuiRuby::TestHelper

  class ViewRenderer
    include Ksef::Helpers
    include Ksef::Tui::Views
    
    attr_accessor :tui, :status, :invoices, :selected_index, :log_entries, :show_detail, :styles_initialized

    def initialize
      @tui = RatatuiRuby::TUI.new
      @invoices = []
      @log_entries = []
      @selected_index = 0
      @status = :disconnected
      @show_detail = false
      
      # Mock styles
      @status_connected = @tui.style(fg: :green)
      @status_loading = @tui.style(fg: :yellow)
      @status_disconnected = @tui.style(fg: :red)
      @title_style = @tui.style(fg: :cyan, modifiers: [:bold])
      @highlight_style = @tui.style(bg: :dark_gray, modifiers: [:bold])
      @header_style = @tui.style(fg: :yellow, modifiers: [:bold])
      @hotkey_style = @tui.style(fg: :yellow)
      @amount_style = @tui.style(fg: :green)
    end
    
    # Helper to access private render methods
    def render_part(method_name, frame, area)
      send(method_name, frame, area)
    end
  end

  def setup
    @renderer = ViewRenderer.new
  end

  def test_render_header_connected
    @renderer.status = :connected
    
    # Use MockFrame and StubRect from TestHelper (conceptually)
    # Since RatatuiRuby::TestHelper mostly provides with_test_terminal, 
    # and MockFrame might not be directly exposed as a class we can instantiate easily 
    # without looking at source, we will use with_test_terminal which passes a frame.
    
    # Use MockFrame for true isolation
    frame = MockFrame.new
    area = StubRect.new(width: 80, height: 5)
    
    @renderer.render_part(:render_header, frame, area)
    
    # Assert on the rendered widget structure
    widget = frame.rendered_widgets.first[:widget]
    
    # Check that it's a paragraph
    assert_kind_of RatatuiRuby::Widgets::Paragraph, widget
    
    # Check content text (the paragraph text is an array of lines)
    # The header has 1 line with multiple spans
    line = widget.text.first
    assert_equal 'KSeF Invoice Viewer', line.spans[0].content
    assert_equal '  ', line.spans[1].content
    assert_equal '● Connected', line.spans[2].content
    
    # Check styles
    assert_equal :green, line.spans[2].style.fg
  end

  def test_render_invoice_table
    @renderer.invoices = [
      { 'ksefNumber' => '123', 'invoiceNumber' => 'INV/001', 'grossAmount' => '100.00', 'currency' => 'PLN' }
    ]
    
    # Use MockFrame
    frame = MockFrame.new
    area = StubRect.new(width: 120, height: 10)
    
    @renderer.render_part(:render_table, frame, area)
    
    # Assert on widget
    widget = frame.rendered_widgets.first[:widget]
    assert_kind_of RatatuiRuby::Widgets::Table, widget
    
    # Check headers
    # widget.header is an array of strings as passed in views.rb
    assert_equal ['KSeF Number', 'Invoice #', 'Date', 'Seller', 'Amount'], widget.header
    
    # Check rows
    assert_equal 1, widget.rows.length
    # Rows are Row objects, cells might be strings or Cell objects
    # Let's check the first row content
    row = widget.rows[0]
    
    # If cells are strings:
    if row.cells.first.is_a?(String)
      assert_equal '123', row.cells[0]
      assert_equal '100.00 PLN', row.cells[4]
    else
      # If cells are objects with content
      assert_equal '123', row.cells[0].content
      assert_equal 'INV/001', row.cells[1].content
      assert_equal '100.00 PLN', row.cells[4].content
    end
  end
end
