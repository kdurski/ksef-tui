# frozen_string_literal: true

require "test_helper"

class InvoicesAuthTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  def setup
    super
    @config_path = File.join(Dir.tmpdir, "invoices_auth_test_#{Process.pid}_#{object_id}.yml")
    File.write(@config_path, <<~YAML)
      settings:
        default_host: "api.default.example"
      profiles:
        - name: "HENTO (testowe)"
          id: "hento-testowe"
          nip: "1111111111"
          token: "seed-token"
          host: "api-test.example"
    YAML
    Profile.config_file = @config_path
  end

  def teardown
    Profile.config_file = nil
    FileUtils.rm_f(@config_path)
    super
  end

  def test_invoice_auth_error_resets_session_and_redirects_to_login
    sign_in

    Ksef::Models::Invoice.stub(:find_all, ->(**) { raise Ksef::AuthError, "expired" }) do
      get invoices_path
    end

    assert_redirected_to new_session_path
    assert_equal "Session expired. Please log in again.", flash[:alert]

    get root_path
    assert_redirected_to new_session_path
  end

  def test_invoice_index_uses_cached_result_for_repeated_loads
    sign_in
    calls = 0
    finder = lambda do |**|
      calls += 1
      [
        Ksef::Models::Invoice.new(
          "ksefNumber" => "KSEF-CACHED",
          "invoiceNumber" => "FV/CACHED",
          "issueDate" => "2026-04-20",
          "seller" => { "name" => "Cached Seller", "nip" => "1234567890" },
          "grossAmount" => "123.00",
          "netAmount" => "100.00",
          "currency" => "PLN",
          "invoiceType" => "VAT"
        )
      ]
    end

    with_memory_cache do
      Ksef::Models::Invoice.stub(:find_all, finder) do
        get invoices_path
        assert_response :success
        assert_includes response.body, "FV/CACHED"
        assert_includes response.body, "Cache status"
        assert_includes response.body, "Last KSeF request:"
        assert_includes response.body, "Expires:"
        assert_includes response.body, "This will call KSeF again and count against the 20 requests/hour limit."
        assert_select "a[href=?][data-turbo-prefetch=?]", invoice_path("KSEF-CACHED"), "false", 7

        get invoices_path
        assert_response :success
        assert_includes response.body, "FV/CACHED"
      end
    end

    assert_equal 1, calls
  end

  def test_invoice_index_displays_cache_timestamps_in_app_time_zone
    sign_in

    finder = lambda do |**|
      [
        Ksef::Models::Invoice.new(
          "ksefNumber" => "KSEF-TIMEZONE",
          "invoiceNumber" => "FV/TIMEZONE",
          "issueDate" => "2026-04-20",
          "seller" => { "name" => "Timezone Seller", "nip" => "1234567890" },
          "grossAmount" => "123.00",
          "netAmount" => "100.00",
          "currency" => "PLN",
          "invoiceType" => "VAT"
        )
      ]
    end

    travel_to Time.utc(2026, 4, 24, 19, 47) do
      with_memory_cache do
        Ksef::Models::Invoice.stub(:find_all, finder) do
          get invoices_path
        end
      end
    end

    assert_response :success
    assert_match(/Last KSeF request:<\/span>\s+24 Apr 21:47/, response.body)
    assert_match(/Expires:<\/span>\s+24 Apr 22:17/, response.body)
  end

  def test_invoice_index_refresh_bypasses_cached_result
    sign_in
    calls = 0
    finder = lambda do |**|
      calls += 1
      [
        Ksef::Models::Invoice.new(
          "ksefNumber" => "KSEF-#{calls}",
          "invoiceNumber" => "FV/#{calls}",
          "issueDate" => "2026-04-20",
          "seller" => { "name" => "Seller #{calls}", "nip" => "1234567890" },
          "grossAmount" => "123.00",
          "netAmount" => "100.00",
          "currency" => "PLN",
          "invoiceType" => "VAT"
        )
      ]
    end

    with_memory_cache do
      Ksef::Models::Invoice.stub(:find_all, finder) do
        get invoices_path
        assert_response :success
        assert_includes response.body, "FV/1"

        get invoices_path(refresh: 1)
        assert_response :success
        assert_includes response.body, "FV/2"
      end
    end

    assert_equal 2, calls
  end

  def test_invoice_index_caches_failed_fetch_metadata
    sign_in
    calls = 0

    with_memory_cache do
      Ksef::Models::Invoice.stub(:find_all, ->(**) { calls += 1; raise Ksef::InvoiceError, "HTTP 429" }) do
        get invoices_path
        assert_response :success
        assert_includes response.body, "Failed to fetch invoices: HTTP 429"
        assert_includes response.body, "Last KSeF request:"
        assert_includes response.body, "Last request failed:"

        get invoices_path
        assert_response :success
        assert_includes response.body, "Failed to fetch invoices: HTTP 429"
      end
    end

    assert_equal 1, calls
  end

  private

  def with_memory_cache(&block)
    Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new, &block)
  end

  def sign_in
    post sessions_path, params: { profile_id: "hento-testowe" }
    login_request = KsefLoginRequest.last
    login_request.complete_success!(
      access_token: "session-token",
      refresh_token: "refresh-token",
      valid_until: "2026-02-20T10:00:00Z",
      refresh_token_valid_until: "2026-02-21T10:00:00Z"
    )

    get finalize_session_path(login_request)
    assert_redirected_to root_path
  end
end
