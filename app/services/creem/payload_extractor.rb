module Creem
  class PayloadExtractor
    class << self
      def event_id(payload)
        explicit_event_id = first(payload, %w[event_id webhook_id], preferred_hashes: [ event_hash(payload) ]) ||
          event_hash(payload)&.dig("id") ||
          event_hash(payload)&.dig(:id)

        return explicit_event_id if explicit_event_id.present?

        digest_source = [ event_type(payload), checkout_id(payload), request_id(payload), payload.to_json ].compact.join(":")
        Digest::SHA256.hexdigest(digest_source)
      end

      def event_type(payload)
        first(payload, %w[event_type type event topic], preferred_hashes: [ event_hash(payload) ])&.to_s
      end

      def checkout_id(payload)
        first(payload, %w[checkout_id id], preferred_hashes: [ checkout_hash(payload) ])
      end

      def request_id(payload)
        first(payload, %w[request_id requestId])
      end

      def order_id(payload)
        first(payload, %w[order_id id transaction_id sale_id], preferred_hashes: [ order_hash(payload) ])
      end

      def license_id(payload)
        first(payload, %w[license_id id], preferred_hashes: [ license_hash(payload) ])
      end

      def license_key(payload)
        first(payload, %w[license_key key code], preferred_hashes: [ license_hash(payload) ])
      end

      def activation_id(payload)
        activation = activation_hash(payload)
        return if activation.blank?

        first(activation, %w[activation_id instance_id seat_id id])
      end

      def customer_email(payload)
        first(
          payload,
          %w[email customer_email],
          preferred_hashes: [ customer_hash(payload), license_hash(payload), order_hash(payload) ]
        )&.downcase
      end

      def max_activations(payload)
        value = first(payload, %w[max_activations activation_limit seats seat_count], preferred_hashes: [ license_hash(payload) ])
        Integer(value, exception: false)
      end

      def status(payload)
        normalize_status(
          first(payload, %w[status state], preferred_hashes: [ license_hash(payload), order_hash(payload), checkout_hash(payload) ])
        )
      end

      def product_ids(payload)
        values = collect(payload, %w[product_id productId])
        values.concat(Array(payload["product_ids"]))
        values.concat(Array(payload[:product_ids]))
        values.concat(Array(payload["products"]).filter_map { |item| item["id"] || item[:id] })
        values.concat(Array(payload["items"]).filter_map { |item| item["product_id"] || item[:product_id] || item["id"] || item[:id] })
        values.compact.map(&:to_s).uniq
      end

      def attributes(payload)
        {
          creem_checkout_id: checkout_id(payload),
          creem_request_id: request_id(payload),
          creem_order_id: order_id(payload),
          creem_license_id: license_id(payload),
          license_key: license_key(payload),
          activation_id: activation_id(payload),
          customer_email: customer_email(payload),
          max_activations: max_activations(payload),
          status: status(payload),
          product_ids: product_ids(payload)
        }
      end

      def event_hash(payload)
        named_hash(payload, %w[event webhook])
      end

      def checkout_hash(payload)
        named_hash(payload, %w[checkout object data]) || first_hash_matching(payload) { |hash| hash.key?("checkout_url") || hash.key?("request_id") }
      end

      def order_hash(payload)
        named_hash(payload, %w[order sale transaction]) || first_hash_matching(payload) { |hash| hash.key?("order_id") || hash.key?("transaction_id") }
      end

      def license_hash(payload)
        named_hash(payload, %w[license feature entitlement]) || first_hash_matching(payload) do |hash|
          hash.key?("license_key") || hash.key?("license_id") || hash.key?("activation_limit") || hash.key?("max_activations")
        end
      end

      def activation_hash(payload)
        named_hash(payload, %w[activation instance seat]) || first_hash_matching(payload) do |hash|
          hash.key?("activation_id") || hash.key?("instance_id") || hash.key?("seat_id")
        end
      end

      def customer_hash(payload)
        named_hash(payload, %w[customer buyer user]) || first_hash_matching(payload) { |hash| hash.key?("email") && hash.keys.length <= 5 }
      end

      private

      def normalize_status(value)
        case value.to_s.downcase
        when "", "paid", "completed", "active", "activated", "valid"
          "active"
        when "pending", "awaiting_payment"
          "pending"
        when "inactive", "deactivated", "expired"
          "inactive"
        when "revoked", "canceled", "cancelled"
          "revoked"
        when "refunded", "chargeback"
          "refunded"
        else
          value.to_s.presence
        end
      end

      def first(payload, candidate_keys, preferred_hashes: [])
        Array(preferred_hashes).compact.each do |hash|
          candidate_keys.each do |key|
            value = hash[key] || hash[key.to_sym]
            return value if present_scalar?(value)
          end
        end

        collect(payload, candidate_keys).find { |value| present_scalar?(value) }
      end

      def collect(node, candidate_keys, values = [])
        case node
        when Hash
          node.each do |key, value|
            values << value if candidate_keys.include?(key.to_s) && present_scalar?(value)
            collect(value, candidate_keys, values)
          end
        when Array
          node.each { |value| collect(value, candidate_keys, values) }
        end

        values
      end

      def named_hash(node, keys)
        case node
        when Hash
          node.each do |key, value|
            return value if keys.include?(key.to_s) && value.is_a?(Hash)

            nested = named_hash(value, keys)
            return nested if nested
          end
        when Array
          node.each do |value|
            nested = named_hash(value, keys)
            return nested if nested
          end
        end

        nil
      end

      def first_hash_matching(node, &block)
        case node
        when Hash
          return node if yield(node)

          node.each_value do |value|
            nested = first_hash_matching(value, &block)
            return nested if nested
          end
        when Array
          node.each do |value|
            nested = first_hash_matching(value, &block)
            return nested if nested
          end
        end

        nil
      end

      def present_scalar?(value)
        !value.is_a?(Hash) && !value.is_a?(Array) && value.present?
      end
    end
  end
end
