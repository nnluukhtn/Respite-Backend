Rails.application.configure do
  config.x.creem = ActiveSupport::OrderedOptions.new
  default_api_base_url = Rails.env.production? ? "https://api.creem.io/v1" : "https://test-api.creem.io/v1"
  config.x.creem.api_base_url = ENV.fetch("CREEM_API_BASE_URL", default_api_base_url)
  config.x.creem.checkout_path = ENV.fetch("CREEM_CHECKOUT_PATH", "/checkouts")
  config.x.creem.checkout_lookup_path = ENV.fetch("CREEM_CHECKOUT_LOOKUP_PATH", "/checkouts")
  config.x.creem.license_activate_path = ENV.fetch("CREEM_LICENSE_ACTIVATE_PATH", "/licenses/activate")
  config.x.creem.license_validate_path = ENV.fetch("CREEM_LICENSE_VALIDATE_PATH", "/licenses/validate")
  config.x.creem.license_deactivate_path = ENV.fetch("CREEM_LICENSE_DEACTIVATE_PATH", "/licenses/deactivate")
  config.x.creem.api_key = ENV["CREEM_API_KEY"]
  config.x.creem.webhook_secret = ENV["CREEM_WEBHOOK_SECRET"]
  config.x.creem.webhook_signature_header = ENV.fetch("CREEM_WEBHOOK_SIGNATURE_HEADER", "HTTP_CREEM_SIGNATURE")
  config.x.creem.success_url = ENV.fetch("CREEM_SUCCESS_URL", "https://example.com/pro/success")
  config.x.creem.cancel_url = ENV.fetch("CREEM_CANCEL_URL", "https://example.com/pro/cancel")
end
