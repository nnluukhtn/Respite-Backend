module Licenses
  class ActivationService
    def initialize(creem_client: Creem::Client.new, synchronizer: Licenses::Synchronizer.new)
      @creem_client = creem_client
      @synchronizer = synchronizer
    end

    def call(license_key:, instance_name:, claim_token: nil)
      raise ApiError.new("Instance name is required", code: "instance_name_required") if instance_name.blank?

      existing_license = synchronizer.find_by_license_key(license_key)
      if existing_license
        raise ApiError.new("This license has been revoked", code: "license_revoked", status: :forbidden) if existing_license.revoked?
        raise ApiError.new("This license has been refunded", code: "license_refunded", status: :forbidden) if existing_license.refunded?

        existing_instance = existing_license.device_activations.active.find_by(instance_name:)
        if existing_instance
          claim_token&.consume! if claim_token&.redeemable?
          claim_token&.checkout_session&.mark_claimed! if claim_token&.checkout_session&.completed?
          return existing_license
        end
      end

      response = creem_client.activate_license(
        license_key: license_key.to_s.strip.upcase,
        instance_name:
      )

      license = synchronizer.upsert_from_license_payload!(response.merge("key" => license_key.to_s.strip.upcase))
      license.update!(status: :active) unless license.active?

      claim_token&.consume! if claim_token&.redeemable?
      claim_token&.checkout_session&.mark_claimed! if claim_token&.checkout_session&.completed?

      license
    end

    private

    attr_reader :creem_client, :synchronizer
  end
end
