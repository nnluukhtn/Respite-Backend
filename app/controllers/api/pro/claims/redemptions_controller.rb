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
            license_key: license.license_key,
            instance_name: params[:instance_name].presence || params[:device_name].presence || params.require(:instance_name),
            claim_token:
          )

          render json: {
            entitlement: entitlement_payload(
              license,
              instance_id: license.device_activations.active.order(activated_at: :desc).first&.creem_instance_id
            )
          }, status: :created
        end
      end
    end
  end
end
