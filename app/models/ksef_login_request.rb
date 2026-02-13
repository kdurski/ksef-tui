# frozen_string_literal: true

class KsefLoginRequest < ApplicationRecord
  enum :status, { pending: 0, succeeded: 1, failed: 2 }

  validates :nip, :seed_token, :host, presence: true

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
end
