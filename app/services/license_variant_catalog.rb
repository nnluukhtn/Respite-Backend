class LicenseVariantCatalog
  class UnknownVariantError < ApiError
    def initialize(identifier)
      super(
        "Unknown license variant: #{identifier}",
        status: :not_found,
        code: "unknown_variant"
      )
    end
  end

  Variant = Data.define(
    :key,
    :creem_product_id,
    :creem_variant_ids,
    :license_type,
    :max_activations
  )

  class << self
    def fetch!(key)
      variant = all[key.to_s]
      raise UnknownVariantError, key unless variant

      variant
    end

    def find_for_product_ids(product_ids)
      normalized_ids = Array(product_ids).flatten.compact.map(&:to_s)

      all.values.find do |variant|
        candidate_ids = [variant.creem_product_id, *variant.creem_variant_ids].compact.map(&:to_s)
        (candidate_ids & normalized_ids).any?
      end
    end

    def find_for_payload(payload)
      product_ids = Array.wrap(payload.deep_symbolize_keys[:product_id])
      product_ids += Array.wrap(payload.deep_symbolize_keys[:product_ids])
      product_ids += Array(payload["products"]).map { |item| item["id"] || item[:id] }
      product_ids += Array(payload["items"]).map { |item| item["product_id"] || item[:product_id] }
      find_for_product_ids(product_ids)
    end

    def all
      @all ||= raw_config.each_with_object({}) do |(key, value), variants|
        variants[key.to_s] = Variant.new(
          key: key.to_s,
          creem_product_id: value.fetch("creem_product_id"),
          creem_variant_ids: Array(value["creem_variant_ids"]),
          license_type: value.fetch("license_type"),
          max_activations: Integer(value.fetch("max_activations"))
        )
      end
    end

    private

    def raw_config
      YAML.safe_load(
        Rails.root.join("config/license_variants.yml").read,
        aliases: true
      ).fetch(Rails.env)
        .with_indifferent_access
    end
  end
end
