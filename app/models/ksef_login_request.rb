# frozen_string_literal: true

class KsefLoginRequest < ApplicationRecord
  enum :status, { pending: 0, succeeded: 1, failed: 2 }

  validates :nip, :seed_token, :host, presence: true
  after_commit :broadcast_status_change, on: :update, if: :saved_change_to_status?

  def complete_success!(tokens)
    update!(
      status: :succeeded,
      access_token: tokens[:access_token],
      refresh_token: tokens[:refresh_token],
      access_token_valid_until: tokens[:valid_until],
      refresh_token_valid_until: tokens[:refresh_token_valid_until],
      error_message: nil,
      completed_at: Time.current
    )
  end

  def complete_failure!(message)
    update!(
      status: :failed,
      error_message: message.to_s,
      completed_at: Time.current
    )
  end

  def status_payload
    payload = { status: status }
    payload[:error_message] = error_message if failed?
    payload[:finalize_url] = Rails.application.routes.url_helpers.finalize_session_path(self) if succeeded?
    payload
  end

  private

  def broadcast_status_change
    LoginRequestStatusChannel.broadcast_to(self, status_payload)
  end
end
