module Licenses
  class DeactivationService
    def initialize(creem_client: Creem::Client.new, synchronizer: Licenses::Synchronizer.new)
      @creem_client = creem_client
      @synchronizer = synchronizer
    end

    def call(license_key:, instance_id: nil, activation_record_id: nil, device_activation: nil)
      license = synchronizer.find_by_license_key(license_key) ||
        synchronizer.ensure_from_credentials!(
          license_key:,
          instance_id:,
          refresh: true
        )

      activation = device_activation || find_activation!(license, instance_id, activation_record_id)
      response = creem_client.deactivate_license(
        license_key: license.license_key || license_key,
        instance_id: activation.creem_instance_id || instance_id
      )

      synchronizer.upsert_from_license_payload!(response.merge("key" => (license.license_key || license_key)))

      activation.update!(
        deactivated_at: Time.current,
        instance_status: "inactive",
        metadata: activation.metadata.merge("deactivation_response" => response)
      )
      license.reload
      license.update!(status: :inactive) if license.current_activations_count.zero? && !license.revoked? && !license.refunded?

      license
    end

    private

    attr_reader :creem_client, :synchronizer

    def find_activation!(license, instance_id, activation_record_id)
      activation = if activation_record_id.present?
        license.device_activations.active.find_by(public_id: activation_record_id)
      elsif instance_id.present?
        license.device_activations.active.find_by(creem_instance_id: instance_id)
      end

      raise ApiError.new("No active instance matched the request", status: :not_found, code: "instance_not_found") unless activation

      activation
    end
  end
end
