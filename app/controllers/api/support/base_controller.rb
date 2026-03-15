module Api
  module Support
    class BaseController < ApplicationController
      before_action :authenticate_support!

      private

      def authenticate_support!
        configured_key = ENV["SUPPORT_API_KEY"].to_s
        provided_key = request.get_header("HTTP_X_SUPPORT_API_KEY").to_s
        raise ApiError.new("Support API key is not configured", status: :service_unavailable, code: "support_not_configured") if configured_key.blank?

        authenticated = ActiveSupport::SecurityUtils.secure_compare(configured_key, provided_key)
        raise ApiError.new("Invalid support API key", status: :unauthorized, code: "support_unauthorized") unless authenticated
      rescue ArgumentError
        raise ApiError.new("Invalid support API key", status: :unauthorized, code: "support_unauthorized")
      end

      def find_license!(reference)
        license = License.find_by(public_id: reference) ||
          License.find_by(creem_license_id: reference) ||
          License.find_by(creem_order_id: reference) ||
          License.find_by(license_key_digest: License.digest_for(reference))

        raise ActiveRecord::RecordNotFound, "Couldn't find License" unless license

        license
      end
    end
  end
end
