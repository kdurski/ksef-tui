# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :pending_login_request_id

    def connect
      self.pending_login_request_id = request.session[:pending_login_request_id].to_s.presence
    end
  end
end
