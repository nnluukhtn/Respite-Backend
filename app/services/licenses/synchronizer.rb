module Licenses
  class Synchronizer
    def initialize(creem_client: Creem::Client.new)
      @creem_client = creem_client
    end

    def ensure_from_credentials!(customer_email:, license_key:, refresh: false)
      normalized_key = license_key.to_s.strip.upcase
      license = License.find_by(license_key_digest: License.digest_for(normalized_key))
      return license if license && !refresh

      payload = creem_client.validate_license(
        license_key: normalized_key,
        customer_email: customer_email.to_s.strip.downcase.presence
      )
      upsert_from_license_payload!(payload)
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

      license = find_existing_license(attributes) || License.new
      license.assign_attributes(
        creem_product_id: attributes[:product_ids].first || variant.creem_product_id,
        creem_variant_id: attributes[:product_ids].find { |id| id != variant.creem_product_id },
        creem_order_id: attributes[:creem_order_id] || license.creem_order_id,
        creem_license_id: attributes[:creem_license_id] || license.creem_license_id,
        license_key: attributes[:license_key].presence || license.license_key,
        license_type: variant.license_type,
        max_activations: attributes[:max_activations] || variant.max_activations,
        status: normalized_status_for(attributes[:status], license),
        customer_email: attributes[:customer_email].presence || license.customer_email,
        metadata: license.metadata.merge(
          "last_creem_sync_at" => Time.current.iso8601,
          "last_creem_payload" => payload
        )
      )
      apply_terminal_timestamps!(license)
      license.save!

      if checkout_session
        checkout_session.update!(
          license:,
          creem_checkout_id: attributes[:creem_checkout_id] || checkout_session.creem_checkout_id,
          creem_request_id: attributes[:creem_request_id] || checkout_session.creem_request_id || checkout_session.public_id,
          creem_product_id: attributes[:product_ids].first || variant.creem_product_id,
          customer_email: attributes[:customer_email].presence || checkout_session.customer_email
        )
      end

      license
    end

    def find_existing_license(attributes)
      if attributes[:creem_license_id].present?
        License.find_by(creem_license_id: attributes[:creem_license_id]) ||
          License.find_by(creem_order_id: attributes[:creem_order_id])
      elsif attributes[:license_key].present?
        License.find_by(license_key_digest: License.digest_for(attributes[:license_key]))
      elsif attributes[:creem_order_id].present?
        License.find_by(creem_order_id: attributes[:creem_order_id])
      end
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
  end
end
