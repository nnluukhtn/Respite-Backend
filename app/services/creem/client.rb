require "json"
require "net/http"

module Creem
  class Client
    def initialize(api_base_url: Rails.configuration.x.creem.api_base_url, api_key: Rails.configuration.x.creem.api_key)
      @api_base_url = api_base_url
      @api_key = api_key
    end

    def create_checkout(variant:, checkout_session:, customer_email: nil, success_url: nil, cancel_url: nil)
      body = {
        product_id: variant.creem_product_id,
        request_id: checkout_session.public_id,
        success_url: success_url || Rails.configuration.x.creem.success_url,
        cancel_url: cancel_url || Rails.configuration.x.creem.cancel_url,
        customer: customer_email.present? ? { email: customer_email } : nil,
        metadata: {
          checkout_session_id: checkout_session.public_id,
          variant_key: checkout_session.variant_key
        }
      }.compact

      response = request(:post, Rails.configuration.x.creem.checkout_path, body:)
      {
        checkout_id: response["id"] || response["checkout_id"],
        request_id: response["request_id"] || checkout_session.public_id,
        checkout_url: response["checkout_url"] || response["url"] || response["hosted_checkout_url"],
        expires_at: response["expires_at"],
        raw: response
      }
    end

    def retrieve_checkout(checkout_id:)
      request(:get, Rails.configuration.x.creem.checkout_lookup_path, params: { checkout_id: })
    end

    def activate_license(license_key:, device_fingerprint:, device_name:, customer_email: nil)
      request(:post, Rails.configuration.x.creem.license_activate_path, body: {
        license_key:,
        email: customer_email,
        device_fingerprint:,
        device_name:
      }.compact)
    end

    def validate_license(license_key:, customer_email: nil, device_fingerprint: nil)
      request(:post, Rails.configuration.x.creem.license_validate_path, body: {
        license_key:,
        email: customer_email,
        device_fingerprint:
      }.compact)
    end

    def deactivate_license(license_key:, customer_email: nil, device_fingerprint: nil, activation_id: nil)
      request(:post, Rails.configuration.x.creem.license_deactivate_path, body: {
        license_key:,
        email: customer_email,
        device_fingerprint:,
        activation_id:
      }.compact)
    end

    private

    attr_reader :api_base_url, :api_key

    def request(method, path, params: nil, body: nil)
      raise Creem::Error.new("Creem API key is not configured", code: "creem_not_configured", status: :service_unavailable) if api_key.blank?

      uri = build_uri(path, params:)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.read_timeout = 15
      http.open_timeout = 5

      request = build_request(method, uri, body:)
      request["Authorization"] = "Bearer #{api_key}"
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json"

      response = http.request(request)
      parsed = parse_body(response.body)

      return parsed if response.is_a?(Net::HTTPSuccess)

      raise Creem::Error.new(
        parsed["message"] || parsed["error"] || "Creem request failed",
        code: "creem_request_failed",
        status: response.code.to_i >= 500 ? :bad_gateway : :unprocessable_entity,
        http_status: response.code.to_i,
        response_body: parsed
      )
    rescue Timeout::Error, Errno::ECONNREFUSED, SocketError => error
      raise Creem::Error.new(
        "Creem connection failed: #{error.message}",
        code: "creem_connection_failed",
        status: :service_unavailable
      )
    end

    def build_uri(path, params: nil)
      uri = URI.join("#{api_base_url}/", path.delete_prefix("/"))
      uri.query = params.to_query if params.present?
      uri
    end

    def build_request(method, uri, body:)
      klass = case method.to_sym
              when :get then Net::HTTP::Get
              when :post then Net::HTTP::Post
              else
                raise ArgumentError, "Unsupported Creem method: #{method}"
              end

      request = klass.new(uri)
      request.body = JSON.generate(body) if body.present?
      request
    end

    def parse_body(raw_body)
      JSON.parse(raw_body.presence || "{}")
    rescue JSON::ParserError
      { "raw_body" => raw_body.to_s }
    end
  end
end
