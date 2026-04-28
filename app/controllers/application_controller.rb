class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  around_action :with_ksef_request_context

  helper_method :current_user_nip, :current_profile_name, :current_environment, :available_profiles

  private

  # Every web request runs inside an explicit KSeF context so library calls
  # can read request-scoped config/client instead of shared global state.
  def with_ksef_request_context
    context = Ksef::Context.new(config: ksef_config)
    Ksef.with_context(context) { yield }
  end

  def current_environment
    host = current_client.host
    host.to_s.include?("test") ? "Test Env" : "Prod Env"
  rescue
    "Unknown"
  end

  def authenticate_session!
    if session[:ksef_token].blank?
      if request.format.html?
        redirect_to new_session_path, alert: "Please sign in to continue"
      else
        head :unauthorized
      end
    end
  end

  def current_client
    @current_client ||= begin
      logger_service = Ksef::DbLogger.new

      # Try to find host in session, or fallback to profile config
      host = session[:ksef_host]
      if host.blank? && (session[:ksef_profile_id].present? || session[:ksef_profile_name].present?)
        profile = if session[:ksef_profile_id].present?
          Profile.find_by(id: session[:ksef_profile_id])
        else
          Profile.find_by(name: session[:ksef_profile_name])
        end
        host = profile&.host
      end

      # Log for debugging
      Rails.logger.info "[AuthDebug] Client Init - SessionHost: #{session[:ksef_host]}, ResolvedHost: #{host}, Profile: #{session[:ksef_profile_name]}"

      client = Ksef::Client.new(
        host: host,
        logger: logger_service
      )

      if session[:ksef_token].present?
        client.update_tokens!(
          access_token: session[:ksef_token],
          access_token_valid_until: session[:ksef_session_until]
        )
      end

      # Expose request-scoped client to legacy call sites still using Ksef.current_client.
      Ksef.current_client = client
      client
    end
  end

  def ksef_config
    @ksef_config ||= Ksef::Config.new
  end

  def available_profiles
    Profile.all
  end

  def current_user_nip
    session[:ksef_nip]
  end

  def current_profile_name
    session[:ksef_profile_name] || "Guest"
  end

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
