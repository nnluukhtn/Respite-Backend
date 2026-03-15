module Licenses
  class ActivationService
    def initialize(creem_client: Creem::Client.new, synchronizer: Licenses::Synchronizer.new)
      @creem_client = creem_client
      @synchronizer = synchronizer
    end

    def call(customer_email:, license_key:, device_fingerprint:, device_name:, claim_token: nil)
      raise ApiError.new("Device fingerprint is required", code: "device_fingerprint_required") if device_fingerprint.blank?
      raise ApiError.new("Device name is required", code: "device_name_required") if device_name.blank?

      license = synchronizer.ensure_from_credentials!(
        customer_email:,
        license_key:,
        refresh: true
      )

      raise ApiError.new("This license has been revoked", code: "license_revoked", status: :forbidden) if license.revoked?
      raise ApiError.new("This license has been refunded", code: "license_refunded", status: :forbidden) if license.refunded?

      existing_activation = license.device_activations.active.find_by(device_fingerprint:)
      if existing_activation
        claim_token&.consume! if claim_token&.redeemable?
        claim_token&.checkout_session&.mark_claimed! if claim_token&.checkout_session&.claimable?
        return license
      end

      if license.current_activations_count >= license.max_activations
        raise ApiError.new("No activation seats are currently available", status: :conflict, code: "activation_capacity_reached")
      end

      response = creem_client.activate_license(
        license_key: license.license_key || license_key,
        customer_email: license.customer_email || customer_email,
        device_fingerprint:,
        device_name:
      )

      license = synchronizer.upsert_from_license_payload!(response.merge("license_key" => (license.license_key || license_key)))

      activation = license.device_activations.new(
        device_fingerprint:,
        device_name:,
        creem_activation_id: Creem::PayloadExtractor.activation_id(response),
        activated_at: Time.current,
        metadata: { "activation_response" => response }
      )
      activation.save!
      license.update!(status: :active)

      claim_token&.consume! if claim_token&.redeemable?
      claim_token&.checkout_session&.mark_claimed! if claim_token&.checkout_session&.claimable?

      license
    end

    private

    attr_reader :creem_client, :synchronizer
  end
end
