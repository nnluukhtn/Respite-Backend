class EntitlementPayloadPresenter
  def initialize(license:, device_fingerprint: nil)
    @license = license
    @device_fingerprint = device_fingerprint
  end

  def as_json(*)
    {
      license_id: license.public_id,
      customer_email: license.customer_email,
      license_type: license.license_type,
      max_activations: license.max_activations,
      current_activations: active_devices.size,
      this_device_active: license.active_for_device?(device_fingerprint),
      status: normalized_status,
      devices: active_and_inactive_devices
    }
  end

  private

  attr_reader :license, :device_fingerprint

  def normalized_status
    return "revoked" if license.revoked?
    return "refunded" if license.refunded?
    return "active" if active_devices.any?
    return "inactive" if license.inactive? || license.pending?

    license.status
  end

  def active_devices
    @active_devices ||= license.active_device_activations.to_a
  end

  def active_and_inactive_devices
    license.device_activations.order(activated_at: :asc).map do |activation|
      {
        id: activation.public_id,
        device_fingerprint: activation.device_fingerprint,
        device_name: activation.device_name,
        creem_activation_id: activation.creem_activation_id,
        activated_at: activation.activated_at&.iso8601,
        deactivated_at: activation.deactivated_at&.iso8601,
        active: activation.active?,
        this_device: activation.device_fingerprint == device_fingerprint
      }
    end
  end
end
