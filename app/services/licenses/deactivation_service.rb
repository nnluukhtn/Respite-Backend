module Licenses
  class DeactivationService
    def initialize(creem_client: Creem::Client.new, synchronizer: Licenses::Synchronizer.new)
      @creem_client = creem_client
      @synchronizer = synchronizer
    end

    def call(customer_email:, license_key:, device_fingerprint: nil, device_id: nil, device_activation: nil)
      license = synchronizer.ensure_from_credentials!(
        customer_email:,
        license_key:,
        refresh: false
      )

      activation = device_activation || find_activation!(license, device_fingerprint, device_id)
      response = creem_client.deactivate_license(
        license_key: license.license_key || license_key,
        customer_email: license.customer_email || customer_email,
        device_fingerprint: activation.device_fingerprint,
        activation_id: activation.creem_activation_id
      )

      activation.update!(
        deactivated_at: Time.current,
        metadata: activation.metadata.merge("deactivation_response" => response)
      )
      license.update!(status: :inactive) if license.device_activations.active.none?

      license
    end

    private

    attr_reader :creem_client, :synchronizer

    def find_activation!(license, device_fingerprint, device_id)
      activation = if device_id.present?
        license.device_activations.active.find_by(public_id: device_id)
      elsif device_fingerprint.present?
        license.device_activations.active.find_by(device_fingerprint:)
      end

      raise ApiError.new("No active device matched the request", status: :not_found, code: "device_activation_not_found") unless activation

      activation
    end
  end
end
