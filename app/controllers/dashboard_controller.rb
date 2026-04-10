class DashboardController < ApplicationController
  def index
    if session[:ksef_token].blank?
      redirect_to new_session_path
      return
    end

    @nip = session[:ksef_nip]
    @valid_until = session[:ksef_session_until]
  end
end
