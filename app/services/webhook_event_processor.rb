class WebhookEventProcessor
  def initialize(synchronizer: Licenses::Synchronizer.new)
    @synchronizer = synchronizer
  end

  def process!(event)
    payload = event.payload.deep_stringify_keys
    event_type = Creem::PayloadExtractor.event_type(payload).to_s

    if purchase_completed?(event_type, payload)
      checkout_session = find_checkout_session(payload)
      license = synchronizer.upsert_from_checkout_payload!(payload, checkout_session:)

      if checkout_session
        checkout_session.mark_claimable!(license:)
        ClaimTokenIssuer.call(
          license:,
          checkout_session:,
          metadata: {
            "event_id" => event.external_event_id,
            "event_type" => event_type
          }
        )
      end
    elsif revocation_event?(event_type)
      revoke_or_refund!(payload, refunded: refunded_event?(event_type))
    elsif checkoutish_payload?(payload)
      checkout_session = find_checkout_session(payload)
      synchronizer.upsert_from_checkout_payload!(payload, checkout_session:)
    end
  end

  private

  attr_reader :synchronizer

  def purchase_completed?(event_type, payload)
    return true if event_type.match?(/checkout\.completed|purchase\.completed|order\.paid|sale\.completed/)

    checkoutish_payload?(payload) && Creem::PayloadExtractor.license_key(payload).present?
  end

  def revocation_event?(event_type)
    event_type.match?(/refund|chargeback|revoke|cancel/)
  end

  def refunded_event?(event_type)
    event_type.match?(/refund|chargeback/)
  end

  def checkoutish_payload?(payload)
    Creem::PayloadExtractor.checkout_id(payload).present? || Creem::PayloadExtractor.request_id(payload).present?
  end

  def find_checkout_session(payload)
    request_id = Creem::PayloadExtractor.request_id(payload)
    checkout_id = Creem::PayloadExtractor.checkout_id(payload)

    CheckoutSession.find_by(public_id: request_id) ||
      CheckoutSession.find_by(creem_request_id: request_id) ||
      CheckoutSession.find_by(creem_checkout_id: checkout_id)
  end

  def revoke_or_refund!(payload, refunded:)
    license = synchronizer.find_existing_from_payload(payload)
    checkout_session = find_checkout_session(payload)

    if license.nil? && checkout_session&.creem_checkout_id.present?
      license = synchronizer.sync_checkout!(checkout_id: checkout_session.creem_checkout_id, checkout_session:)
    end

    return unless license

    timestamp = Time.current
    license.update!(
      status: refunded ? :refunded : :revoked,
      refunded_at: refunded ? timestamp : license.refunded_at,
      revoked_at: refunded ? license.revoked_at : timestamp,
      metadata: license.metadata.merge("last_revocation_payload" => payload)
    )
    license.device_activations.active.find_each { |activation| activation.deactivate!(timestamp:) }
    license.checkout_sessions.update_all(status: refunded ? CheckoutSession.statuses[:refunded] : CheckoutSession.statuses[:revoked])
  end
end
