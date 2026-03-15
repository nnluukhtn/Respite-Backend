module Api
  module Support
    class LicensesController < BaseController
      def show
        license = find_license!(params[:reference])
        render json: {
          license: entitlement_payload(license, device_fingerprint: params[:device_fingerprint]),
          creem: {
            creem_product_id: license.creem_product_id,
            creem_order_id: license.creem_order_id,
            creem_license_id: license.creem_license_id
          }
        }
      end

      def activations
        license = find_license!(params[:reference])
        render json: {
          activations: entitlement_payload(license, device_fingerprint: params[:device_fingerprint])[:devices]
        }
      end

      def release
        license = find_license!(params[:reference])
        activation = if params[:device_id].present?
          license.device_activations.active.find_by!(public_id: params[:device_id])
        elsif params[:device_fingerprint].present?
          license.device_activations.active.find_by!(device_fingerprint: params[:device_fingerprint])
        else
          raise ApiError.new("device_id or device_fingerprint is required", status: :bad_request, code: "missing_release_target")
        end

        if license.license_key.present?
          license = Licenses::DeactivationService.new.call(
            customer_email: license.customer_email,
            license_key: license.license_key,
            device_activation: activation
          )
        else
          activation.deactivate!
          license.update!(status: :inactive) if license.device_activations.active.none?
        end

        render json: {
          entitlement: entitlement_payload(license)
        }
      end

      def resend_claim_link
        license = find_license!(params[:reference])
        checkout_session = license.checkout_sessions.order(created_at: :desc).first
        claim = ClaimTokenIssuer.call(
          license:,
          checkout_session:,
          metadata: { "source" => "support_resend" }
        )

        delivered = false
        if license.customer_email.present?
          begin
            ClaimMailer.claim_link(
              email: license.customer_email,
              claim_url: claim[:claim_url],
              license:
            ).deliver_now
            delivered = true
          rescue StandardError
            delivered = false
          end
        end

        render json: {
          claim_url: claim[:claim_url],
          delivered:
        }, status: :created
      end
    end
  end
end
