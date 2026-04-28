require "csv"
require "digest"

class InvoicesController < ApplicationController
  INVOICE_LIST_CACHE_TTL = 30.minutes

  class InvoiceDownloadError < StandardError
    attr_reader :status

    def initialize(message, status: :bad_gateway)
      @status = status
      super(message)
    end
  end

  before_action :authenticate_session!
  before_action :build_filter, only: [ :index, :download_csv ]

  def index
    @invoices = []
    return unless @filter.valid?

    cached_result = cached_invoice_list_result

    @invoice_cache_fetched_at = local_cache_time(cached_result[:fetched_at])
    @invoice_cache_expires_at = @invoice_cache_fetched_at + INVOICE_LIST_CACHE_TTL if @invoice_cache_fetched_at
    @invoice_cache_error = cached_result[:error]
    @invoices = cached_result.fetch(:invoices, []).map { |invoice_data| Ksef::Models::Invoice.new(invoice_data) }
    flash.now[:alert] = "Failed to fetch invoices: #{@invoice_cache_error}" if @invoice_cache_error.present?
  rescue Ksef::AuthError
    handle_session_expired_error
  rescue Ksef::InvoiceError => e
    return handle_session_expired_error if session_expired_error?(e)

    handle_invoice_fetch_error(e, redirect_on_error: false)
  end

  def download_csv
    unless @filter.valid?
      redirect_to invoices_path(@filter.request_params), alert: @filter.error
      return
    end

    invoices = load_invoices(query_params: @filter.query_params, redirect_on_error: true)
    return if performed?

    send_data invoices_to_csv(invoices),
      filename: "invoices-#{Date.current.iso8601}.csv",
      type: "text/csv; charset=utf-8",
      disposition: "attachment"
  end

  def show
    begin
      @invoice = Ksef::Models::Invoice.find(ksef_number: params[:id], client: current_client)
    rescue => e
      redirect_to invoices_path, alert: "Invoice not found or error loading: #{e.message}"
    end
  end

  def xml
    xml_content = fetch_invoice_xml!(params[:id])
    render plain: xml_content, content_type: "application/xml"
  rescue InvoiceDownloadError => e
    render plain: e.message, status: e.status
  end

  def download
    ksef_number = params[:id]
    begin
      xml_content = fetch_invoice_xml!(ksef_number)
      send_data xml_content, filename: "#{ksef_number}.xml", type: "application/xml", disposition: "attachment"
    rescue InvoiceDownloadError => e
      redirect_to invoice_path(ksef_number), alert: "Failed to download XML: #{e.message}"
    end
  end

  private

  def build_filter
    @filter = Invoices::DateFilter.new(params)
  end

  def load_invoices(query_params:, redirect_on_error: false)
    Ksef::Models::Invoice.find_all(query_body: query_params, client: current_client)
  rescue Ksef::AuthError
    handle_session_expired_error
  rescue Ksef::InvoiceError => e
    return handle_session_expired_error if session_expired_error?(e)

    handle_invoice_fetch_error(e, redirect_on_error: redirect_on_error)
  rescue => e
    handle_invoice_fetch_error(e, redirect_on_error: redirect_on_error)
  end

  def cached_invoice_list_result
    Rails.cache.delete(invoice_list_cache_key) if refresh_invoice_cache?

    Rails.cache.fetch(invoice_list_cache_key, expires_in: INVOICE_LIST_CACHE_TTL) do
      invoices = Ksef::Models::Invoice.find_all(query_body: @filter.query_params, client: current_client)

      {
        fetched_at: Time.current,
        invoices: invoices.map(&:raw_data),
        error: nil
      }
    rescue Ksef::AuthError
      raise
    rescue Ksef::InvoiceError => e
      raise if session_expired_error?(e)

      cached_invoice_error_result(e)
    rescue => e
      cached_invoice_error_result(e)
    end
  end

  def cached_invoice_error_result(error)
    {
      fetched_at: Time.current,
      invoices: [],
      error: error.message
    }
  end

  def refresh_invoice_cache?
    params[:refresh].present?
  end

  def local_cache_time(time)
    time&.in_time_zone
  end

  def invoice_list_cache_key
    key_parts = {
      host: session[:ksef_host],
      nip: session[:ksef_nip],
      profile_id: session[:ksef_profile_id],
      query_params: @filter.query_params
    }

    "ksef/invoices/index/#{Digest::SHA256.hexdigest(key_parts.to_json)}"
  end

  def invoices_to_csv(invoices)
    CSV.generate do |csv|
      csv << [
        "Invoice issue date",
        "Seller name",
        "Net total amount (excluding VAT)",
        "Total amount including VAT",
        "Currency"
      ]

      invoices.each do |invoice|
        csv << [
          invoice.issue_date,
          sanitize_csv_text_cell(invoice.seller_name),
          invoice.net_amount,
          invoice.gross_amount,
          invoice.currency
        ]
      end
    end
  end

  def sanitize_csv_text_cell(value)
    return value if value.blank?
    return value unless value.match?(/\A[[:space:]]*[=+\-@]/)

    "'#{value}"
  end

  def fetch_invoice_xml!(ksef_number)
    response = current_client.get_xml("/invoices/ksef/#{CGI.escape(ksef_number)}")
    return response if response.is_a?(String)

    if response.is_a?(Hash)
      status = Integer(response["http_status"], exception: false)
      status = :bad_gateway if status.nil? || status < 400
      raise InvoiceDownloadError.new(response["error"] || "Failed to fetch invoice XML", status: status)
    end

    raise InvoiceDownloadError.new("Invalid XML invoice response")
  end

  def session_expired_error?(error)
    return true if [ 401, 403 ].include?(Integer(error.http_status, exception: false))

    error.message.to_s.match?(/\AHTTP (401|403)\z/)
  end

  def handle_session_expired_error
    reset_session
    redirect_to new_session_path, alert: "Session expired. Please log in again."
    []
  end

  def handle_invoice_fetch_error(error, redirect_on_error:)
    message = "Failed to fetch invoices: #{error.message}"

    if redirect_on_error
      redirect_to invoices_path(@filter.request_params), alert: message
    else
      flash.now[:alert] = message
    end

    []
  end
end
