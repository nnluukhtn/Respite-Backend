module Api
  module Pro
    module Claims
      class RedemptionsController < ApplicationController
        def create
          claim_token = ClaimToken.find_by!(token_digest: ClaimToken.digest_for(params.require(:claim_token)))
          raise ApiError.new("Claim token has expired", status: :gone, code: "claim_token_expired") unless claim_token.redeemable?

          license = claim_token.license || claim_token.checkout_session&.license
          if license.nil? && claim_token.checkout_session&.creem_checkout_id.present?
            license = Licenses::Synchronizer.new.sync_checkout!(
              checkout_id: claim_token.checkout_session.creem_checkout_id,
              checkout_session: claim_token.checkout_session
            )
          end

          raise ApiError.new("The purchase is not claimable yet", status: :conflict, code: "claim_not_ready") unless license
          raise ApiError.new("A license key is not available for this claim yet", status: :conflict, code: "claim_license_key_missing") if license.license_key.blank?

          license = Licenses::ActivationService.new.call(
            customer_email: license.customer_email,
            license_key: license.license_key,
            device_fingerprint: params.require(:device_fingerprint),
            device_name: params.require(:device_name),
            claim_token:
          )

          render json: {
            entitlement: entitlement_payload(
              license,
              device_fingerprint: params[:device_fingerprint]
            )
          }, status: :created
        end
      end
    end
  end
end
