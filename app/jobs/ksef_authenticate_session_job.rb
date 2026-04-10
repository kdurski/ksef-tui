# frozen_string_literal: true

class KsefAuthenticateSessionJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(login_request_id)
    login_request = nil
    login_request = KsefLoginRequest.find(login_request_id)
    return unless login_request.pending?

    logger_service = Ksef::DbLogger.new
    client = Ksef::Client.new(host: login_request.host, logger: logger_service)
    auth = Ksef::Auth.new(client: client, nip: login_request.nip, access_token: login_request.seed_token)

    tokens = auth.authenticate

    sleep 10

    login_request.complete_success!(tokens)
  rescue ActiveRecord::RecordNotFound
    raise
  rescue Ksef::AuthError, ArgumentError => e
    login_request&.complete_failure!(e.message)
  rescue => e
    login_request&.complete_failure!("System error: #{e.message}")
  end
end
