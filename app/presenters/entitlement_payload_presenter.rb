class EntitlementPayloadPresenter
  def initialize(license:, instance_id: nil)
    @license = license
    @instance_id = instance_id
  end

  def as_json(*)
    instances = known_instances

    {
      license_id: license.public_id,
      customer_email: license.customer_email,
      creem_customer_id: license.creem_customer_id,
      license_type: license.license_type,
      license_key_last4: license.license_key_last4,
      max_activations: license.max_activations,
      current_activations: license.current_activations_count,
      expires_at: license.expires_at&.iso8601,
      this_instance_active: license.active_for_instance?(instance_id),
      status: normalized_status,
      instances:,
      devices: instances
    }
  end

  private

  attr_reader :license, :instance_id

  def normalized_status
    return "revoked" if license.revoked?
    return "refunded" if license.refunded?
    return "disabled" if license.disabled?
    return "expired" if license.expired?
    return "active" if license.current_activations_count.positive?
    return "inactive" if license.inactive? || license.pending?

    license.status
  end

  def known_instances
    license.device_activations.order(activated_at: :asc).map do |activation|
      {
        id: activation.public_id,
        instance_id: activation.creem_instance_id,
        instance_name: activation.instance_name,
        status: activation.instance_status,
        activated_at: activation.activated_at&.iso8601,
        deactivated_at: activation.deactivated_at&.iso8601,
        active: activation.active?,
        this_instance: activation.creem_instance_id == instance_id,
        device_name: activation.instance_name
      }
    end
  end
end
