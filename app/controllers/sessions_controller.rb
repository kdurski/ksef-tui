class SessionsController < ApplicationController
  layout :resolve_layout
  before_action :load_profiles, only: [ :new, :create ]
  before_action :load_login_request, only: [ :show, :status, :finalize ]

  def new
  end

  def create
    payload = login_payload
    if payload.nil?
      render :new, status: :unprocessable_entity
      return
    end

    login_request = KsefLoginRequest.create!(payload)
    KsefAuthenticateSessionJob.perform_later(login_request.id)

    session[:pending_login_request_id] = login_request.id
    redirect_to session_path(login_request)
  end

  def show
    return if @login_request.pending?

    redirect_to finalize_session_path(@login_request) if @login_request.succeeded?
  end

  def status
    render json: @login_request.status_payload
  end

  def finalize
    if @login_request.failed?
      session.delete(:pending_login_request_id)
      redirect_to new_session_path, alert: "Authentication failed: #{@login_request.error_message}"
      return
    end

    unless @login_request.succeeded?
      redirect_to session_path(@login_request)
      return
    end

    set_authenticated_session!(@login_request)
    redirect_to root_path, notice: "Logged in successfully to KSeF"
  end

  def destroy
    # Ideally call Logout API
    reset_session
    redirect_to new_session_path, notice: "Logged out"
  end

  private

  def resolve_layout
    session[:ksef_token].blank? ? "auth" : "application"
  end

  def set_authenticated_session!(login_request)
    reset_session

    session[:ksef_token] = login_request.access_token
    session[:ksef_session_until] = login_request.access_token_valid_until
    session[:ksef_nip] = login_request.nip
    session[:ksef_host] = login_request.host
    session[:ksef_profile_id] = login_request.profile_id
    session[:ksef_profile_name] = login_request.profile_name || "Manual Auth"
    session[:ksef_environment] = login_request.host.to_s.include?("test") ? "test" : "prod"
  end

  def load_profiles
    @profiles = available_profiles
  end

  def load_login_request
    @login_request = KsefLoginRequest.find(params[:id])

    return if session[:pending_login_request_id].to_s == @login_request.id.to_s

    redirect_to new_session_path, alert: "Login request expired"
  end

  def login_payload
    profile = selected_profile
    if profile
      return {
        profile_id: profile.id,
        profile_name: profile.name,
        nip: profile.nip,
        seed_token: profile.token,
        host: profile.host
      }
    end

    nip = params[:nip].to_s
    token = params[:token].to_s
    if nip.blank? || token.blank?
      flash.now[:alert] = "NIP and Token are required"
      return nil
    end

    {
      profile_name: "Manual Auth",
      nip: nip,
      seed_token: token,
      host: Profile.default_host
    }
  end

  def selected_profile
    key = params[:profile_id].presence || params[:profile_name].presence
    return nil if key.blank?

    profile = Profile.find_by(id: key) || Profile.find_by(name: key)
    return profile if profile

    flash.now[:alert] = "Profile not found"
    nil
  end
end
