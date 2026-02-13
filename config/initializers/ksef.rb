# Initialize KSeF configuration
Rails.application.config.to_prepare do
  # Force autoload of Ksef::Config to ensure Ksef.config method is defined
  Ksef::Config

  # Load the configuration from ~/.ksef.yml
  Ksef.config
rescue => e
  Rails.logger.warn "Failed to load KSeF configuration: #{e.message}"
end
