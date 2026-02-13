# frozen_string_literal: true

class LoginRequestStatusChannel < ApplicationCable::Channel
  def subscribed
    login_request = KsefLoginRequest.find_by(id: params[:login_request_id])
    reject and return unless login_request
    reject and return unless pending_login_request_id.to_s == login_request.id.to_s

    stream_for login_request
  end
end
