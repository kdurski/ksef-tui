require "csv"

class InvoicesController < ApplicationController
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
    @invoices = @filter.valid? ? load_invoices(query_params: @filter.query_params) : []
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
  rescue Ksef::InvoiceError => e
    return handle_session_expired_error if session_expired_error?(e)

    handle_invoice_fetch_error(e, redirect_on_error: redirect_on_error)
  rescue => e
    handle_invoice_fetch_error(e, redirect_on_error: redirect_on_error)
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
