class SessionsController < ApplicationController
  layout "auth"
  before_action :load_profiles, only: [ :new, :create ]

  def new
  end

  def create
    host = nil

    if params[:profile_name].present?
      profile = Profile.find_by(name: params[:profile_name])
      if profile
        nip = profile.nip
        token = profile.token
        host = profile.host
        Rails.logger.info "[AuthDebug] Profile: #{profile.name}, Host: #{host}"
      else
        flash.now[:alert] = "Profile not found"
        render :new, status: :unprocessable_entity
        return
      end
    else
      nip = params[:nip]
      token = params[:token]
      host = Profile.default_host
    end

    if nip.blank? || token.blank?
      flash.now[:alert] = "NIP and Token are required"
      render :new, status: :unprocessable_entity
      return
    end

    # Use DbLogger
    logger_service = Ksef::DbLogger.new
    # Client for auth (no token yet)
    client = Ksef::Client.new(host: host, logger: logger_service)

    auth = Ksef::Auth.new(client: client, nip: nip, access_token: token)

    begin
      tokens = auth.authenticate

      # Store in session
      reset_session
      session[:ksef_token] = tokens[:access_token]
      session[:ksef_session_until] = tokens[:valid_until]
      session[:ksef_nip] = nip
      session[:ksef_host] = host
      session[:ksef_profile_name] = params[:profile_name] || "Manual Auth"
      session[:ksef_environment] = host.to_s.include?("test") ? "test" : "prod"

      redirect_to root_path, notice: "Logged in successfully to KSeF"
    rescue Ksef::AuthError => e
      flash.now[:alert] = "Authentication failed: #{e.message}"
      render :new, status: :unprocessable_entity
    rescue => e
      flash.now[:alert] = "System error: #{e.message}"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    # Ideally call Logout API
    reset_session
    redirect_to new_session_path, notice: "Logged out"
  end

  private

  def load_profiles
    @profiles = available_profiles
  end
end
