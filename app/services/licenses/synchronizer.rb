module Licenses
  class Synchronizer
    def initialize(creem_client: Creem::Client.new)
      @creem_client = creem_client
    end

    def ensure_from_credentials!(customer_email: nil, license_key:, instance_id: nil, refresh: false)
      normalized_key = license_key.to_s.strip.upcase
      license = find_by_license_key(normalized_key)
      return license if license && !refresh

      payload = creem_client.validate_license(
        license_key: normalized_key,
        instance_id:
      )

      upsert_from_license_payload!(
        payload.merge(
          "key" => normalized_key,
          "customer_email" => customer_email.to_s.strip.downcase.presence || payload["customer_email"]
        )
      )
    end

    def find_by_license_key(license_key)
      normalized_key = license_key.to_s.strip.upcase
      return if normalized_key.blank?

      License.find_by(license_key_digest: License.digest_for(normalized_key))
    end

    def sync_checkout!(checkout_id:, checkout_session: nil)
      payload = creem_client.retrieve_checkout(checkout_id:)
      upsert_from_checkout_payload!(payload, checkout_session:)
    end

    def upsert_from_checkout_payload!(payload, checkout_session: nil)
      upsert_license!(payload, checkout_session:, default_variant: variant_for_checkout(checkout_session, payload))
    end

    def upsert_from_license_payload!(payload)
      upsert_license!(payload, default_variant: LicenseVariantCatalog.find_for_payload(payload))
    end

    def find_existing_from_payload(payload)
      attributes = Creem::PayloadExtractor.attributes(payload)
      find_existing_license(attributes)
    end

    private

    attr_reader :creem_client

    def upsert_license!(payload, checkout_session: nil, default_variant:)
      attributes = Creem::PayloadExtractor.attributes(payload)
      variant = default_variant || LicenseVariantCatalog.find_for_product_ids(attributes[:product_ids])
      raise ApiError.new("Unable to map Creem payload to a license variant", code: "variant_mapping_missing") unless variant

      existing_license = find_existing_license(attributes)
      resolved_max_activations = attributes[:max_activations] || license_max_activations_for(
        variant,
        existing_license,
        checkout_session,
        attributes
      )

      if resolved_max_activations.blank?
        raise ApiError.new(
          "Enterprise licenses require max activations metadata from Creem or manual provisioning",
          code: "enterprise_capacity_missing"
        )
      end

      license = existing_license || License.new
      license.assign_attributes(
        creem_product_id: attributes[:product_ids].first || variant.creem_product_id,
        creem_variant_id: attributes[:product_ids].find { |id| id != variant.creem_product_id },
        creem_customer_id: attributes[:creem_customer_id] || license.creem_customer_id,
        creem_order_id: attributes[:creem_order_id] || license.creem_order_id,
        creem_license_id: attributes[:creem_license_id] || license.creem_license_id,
        license_key: attributes[:license_key].presence || license.license_key,
        license_type: variant.license_type,
        max_activations: resolved_max_activations,
        current_activations_count: attributes[:current_activations] || license.current_activations_count || 0,
        status: normalized_status_for(attributes[:status], license),
        customer_email: attributes[:customer_email].presence || license.customer_email,
        expires_at: parsed_timestamp(attributes[:expires_at]) || license.expires_at,
        metadata: license.metadata.merge(
          "last_creem_sync_at" => Time.current.iso8601,
          "last_creem_payload" => payload
        )
      )
      apply_terminal_timestamps!(license)
      license.save!

      sync_instance_record!(license, attributes, payload)

      if checkout_session
        checkout_session.update!(
          license:,
          creem_checkout_id: attributes[:creem_checkout_id] || checkout_session.creem_checkout_id,
          creem_request_id: attributes[:creem_request_id] || checkout_session.creem_request_id || checkout_session.public_id,
          creem_product_id: attributes[:product_ids].first || variant.creem_product_id,
          customer_email: attributes[:customer_email].presence || checkout_session.customer_email,
          units: attributes[:units] || checkout_session.units
        )
      end

      license
    end

    def find_existing_license(attributes)
      if attributes[:creem_license_id].present?
        License.find_by(creem_license_id: attributes[:creem_license_id]) ||
          License.find_by(creem_order_id: attributes[:creem_order_id])
      elsif attributes[:license_key].present?
        find_by_license_key(attributes[:license_key])
      elsif attributes[:creem_order_id].present?
        License.find_by(creem_order_id: attributes[:creem_order_id])
      end
    end

    def license_max_activations_for(variant, existing_license, checkout_session, attributes)
      return existing_license.max_activations if existing_license&.max_activations.present?
      return variant.max_activations unless variant.custom_capacity
      return attributes[:units] if attributes[:units].present?
      return checkout_session.units if checkout_session&.units.present?

      nil
    end

    def variant_for_checkout(checkout_session, payload)
      return LicenseVariantCatalog.fetch!(checkout_session.variant_key) if checkout_session

      LicenseVariantCatalog.find_for_payload(payload)
    rescue LicenseVariantCatalog::UnknownVariantError
      nil
    end

    def normalized_status_for(extracted_status, license)
      case extracted_status.presence || license&.status
      when "revoked" then "revoked"
      when "refunded" then "refunded"
      when "disabled" then "disabled"
      when "expired" then "expired"
      when "inactive" then "inactive"
      when "pending" then "pending"
      else
        "active"
      end
    end

    def apply_terminal_timestamps!(license)
      license.revoked_at ||= Time.current if license.revoked?
      license.refunded_at ||= Time.current if license.refunded?
    end

    def sync_instance_record!(license, attributes, payload)
      return if attributes[:instance_id].blank? && attributes[:instance_name].blank?

      activation = if attributes[:instance_id].present?
        license.device_activations.find_by(creem_instance_id: attributes[:instance_id])
      end
      activation ||= license.device_activations.active.find_by(instance_name: attributes[:instance_name]) if attributes[:instance_name].present?
      activation ||= license.device_activations.find_by(instance_name: attributes[:instance_name]) if attributes[:instance_name].present?
      activation ||= license.device_activations.new

      active_instance = if attributes[:instance_status].present?
        attributes[:instance_status].to_s.casecmp("active").zero?
      else
        license.active?
      end
      active_instance &&= !license.revoked? && !license.refunded?

      activation.assign_attributes(
        creem_instance_id: attributes[:instance_id] || activation.creem_instance_id,
        instance_name: attributes[:instance_name] || activation.instance_name || "Unknown instance",
        instance_status: attributes[:instance_status].presence || (active_instance ? "active" : "inactive"),
        activated_at: activation.activated_at || Time.current,
        last_validated_at: Time.current,
        metadata: activation.metadata.merge("last_creem_payload" => payload)
      )
      activation.deactivated_at ||= Time.current unless active_instance
      activation.deactivated_at = nil if active_instance
      activation.save!
    end

    def parsed_timestamp(value)
      return if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
