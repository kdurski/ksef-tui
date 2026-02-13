class InvoicesController < ApplicationController
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
    rescue Ksef::AuthError => e
      redirect_to logout_path, alert: "Session expired. Please log in again."
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


  def download
    ksef_number = params[:id]
    begin
      xml_content = current_client.get_xml("/invoices/ksef/#{CGI.escape(ksef_number)}")
      send_data xml_content, filename: "#{ksef_number}.xml", type: "application/xml", disposition: "attachment"
    rescue => e
      redirect_to invoice_path(ksef_number), alert: "Failed to download XML: #{e.message}"
    end
  end
end
