module Creem
  class WebhookSignatureVerifier
    def self.verify!(raw_payload:, request:)
      secret = Rails.configuration.x.creem.webhook_secret
      return true if secret.blank? && !Rails.env.production?

      provided_signature = extract_signature(request)
      raise ApiError.new("Missing Creem webhook signature", status: :unauthorized, code: "missing_signature") if provided_signature.blank?

      expected_signature = OpenSSL::HMAC.hexdigest("SHA256", secret.to_s, raw_payload)
      candidate_signatures = [
        expected_signature,
        "sha256=#{expected_signature}"
      ]

      matches = candidate_signatures.any? do |candidate|
        ActiveSupport::SecurityUtils.secure_compare(candidate, provided_signature)
      rescue ArgumentError
        false
      end

      raise ApiError.new("Invalid Creem webhook signature", status: :unauthorized, code: "invalid_signature") unless matches

      true
    end

    def self.extract_signature(request)
      header_name = Rails.configuration.x.creem.webhook_signature_header
      possible_headers = [
        header_name,
        header_name.sub(/\AHTTP_/, ""),
        "HTTP_X_CREEM_SIGNATURE",
        "HTTP_CREEM_SIGNATURE",
        "X-Creem-Signature",
        "Creem-Signature"
      ]

      possible_headers.lazy.map { |name| request.get_header(name) || request.headers[name] }.find(&:present?)
    end
  end
end
