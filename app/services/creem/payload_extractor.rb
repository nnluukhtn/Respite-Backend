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
        first(payload, %w[event_type eventType type event topic], preferred_hashes: [ event_hash(payload) ])&.to_s
      end

      def checkout_id(payload)
        first(payload, %w[checkout_id id], preferred_hashes: [ checkout_hash(payload) ])
      end

      def request_id(payload)
        first(payload, %w[request_id requestId], preferred_hashes: [ checkout_hash(payload) ])
      end

      def order_id(payload)
        first(payload, %w[order_id id transaction_id sale_id], preferred_hashes: [ order_hash(payload) ])
      end

      def license_id(payload)
        first(payload, %w[license_id id], preferred_hashes: [ primary_license_hash(payload) ])
      end

      def license_key(payload)
        first(payload, %w[license_key key code], preferred_hashes: [ primary_license_hash(payload) ])
      end

      def instance_id(payload)
        first(payload, %w[instance_id id], preferred_hashes: [ instance_hash(payload) ])
      end

      def instance_name(payload)
        first(payload, %w[instance_name name], preferred_hashes: [ instance_hash(payload) ])
      end

      def instance_status(payload)
        first(payload, %w[status state], preferred_hashes: [ instance_hash(payload) ])&.to_s
      end

      def customer_email(payload)
        first(
          payload,
          %w[email customer_email],
          preferred_hashes: [ customer_hash(payload), primary_license_hash(payload), order_hash(payload) ]
        )&.downcase
      end

      def customer_id(payload)
        value = first(payload, %w[customer_id id], preferred_hashes: [ customer_hash(payload) ])
        value&.to_s
      end

      def max_activations(payload)
        value = first(
          payload,
          %w[max_activations activation_limit seats seat_count quantity units],
          preferred_hashes: [ primary_license_hash(payload), checkout_hash(payload) ]
        )
        Integer(value, exception: false)
      end

      def current_activations(payload)
        value = first(
          payload,
          %w[current_activations activation_count active_activations],
          preferred_hashes: [ primary_license_hash(payload) ]
        )
        Integer(value, exception: false)
      end

      def expires_at(payload)
        first(payload, %w[expires_at expiresAt], preferred_hashes: [ primary_license_hash(payload), checkout_hash(payload) ])
      end

      def units(payload)
        value = first(payload, %w[units quantity], preferred_hashes: [ checkout_hash(payload) ])
        Integer(value, exception: false)
      end

      def status(payload)
        normalize_status(
          first(payload, %w[status state], preferred_hashes: [ primary_license_hash(payload), order_hash(payload), checkout_hash(payload) ])
        )
      end

      def product_ids(payload)
        values = collect(payload, %w[product_id productId])
        values.concat(Array(payload["product_ids"]))
        values.concat(Array(payload[:product_ids]))
        values.concat(Array(payload["products"]).filter_map { |item| item["id"] || item[:id] })
        values.concat(Array(payload["items"]).filter_map { |item| item["product_id"] || item[:product_id] || item["id"] || item[:id] })

        product = payload["product"] || payload[:product]
        values << (product["id"] || product[:id]) if product.is_a?(Hash)
        values << product if product.is_a?(String)
        checkout_product = checkout_hash(payload)&.dig("product") || checkout_hash(payload)&.dig(:product)
        values << (checkout_product["id"] || checkout_product[:id]) if checkout_product.is_a?(Hash)
        values << checkout_product if checkout_product.is_a?(String)

        values.compact.map(&:to_s).uniq
      end

      def attributes(payload)
        {
          creem_checkout_id: checkout_id(payload),
          creem_request_id: request_id(payload),
          creem_order_id: order_id(payload),
          creem_license_id: license_id(payload),
          creem_customer_id: customer_id(payload),
          license_key: license_key(payload),
          instance_id: instance_id(payload),
          instance_name: instance_name(payload),
          instance_status: instance_status(payload),
          customer_email: customer_email(payload),
          max_activations: max_activations(payload),
          current_activations: current_activations(payload),
          expires_at: expires_at(payload),
          status: status(payload),
          product_ids: product_ids(payload),
          units: units(payload)
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

      def instance_hash(payload)
        named_hash(payload, %w[instance activation seat]) || first_hash_matching(payload) do |hash|
          hash.key?("instance_id") || hash.key?("instance_name")
        end
      end

      def customer_hash(payload)
        named_hash(payload, %w[customer buyer user]) || first_hash_matching(payload) do |hash|
          hash.key?("email") || hash.key?("customer_id")
        end
      end

      private

      def primary_license_hash(payload)
        license_key_objects(payload).find { |item| item.is_a?(Hash) } || license_hash(payload)
      end

      def license_key_objects(payload)
        objects = []
        objects.concat(Array(payload["license_keys"]))
        objects.concat(Array(payload[:license_keys]))

        features = Array(payload["features"]) + Array(payload[:features]) + Array(payload["feature"]) + Array(payload[:feature])
        objects.concat(features.filter_map { |item| item["license_key"] || item[:license_key] || item["license"] || item[:license] })
        objects.compact
      end

      def normalize_status(value)
        case value.to_s.downcase
        when "", "paid", "completed", "active", "activated", "valid"
          "active"
        when "pending", "awaiting_payment"
          "pending"
        when "inactive", "deactivated"
          "inactive"
        when "expired"
          "expired"
        when "disabled"
          "disabled"
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
