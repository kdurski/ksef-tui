class InvoicesController < ApplicationController
  class InvoiceDownloadError < StandardError
    attr_reader :status

    def initialize(message, status: :bad_gateway)
      @status = status
      super(message)
    end
  end

  before_action :authenticate_session!

  def index
    @query_params = {
      subjectType: Ksef::Client::SUBJECT_TYPES[:buyer],
      dateRange: {
        dateType: "PermanentStorage",
        from: (Time.now - 30.days).iso8601,
        to: Time.now.iso8601
      }
    }

    begin
      @invoices = Ksef::Models::Invoice.find_all(query_body: @query_params, client: current_client)
    rescue Ksef::InvoiceError => e
      raise unless session_expired_error?(e)

      reset_session
      redirect_to new_session_path, alert: "Session expired. Please log in again."
    rescue => e
      flash.now[:alert] = "Failed to fetch invoices: #{e.message}"
      @invoices = []
    end
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
end
