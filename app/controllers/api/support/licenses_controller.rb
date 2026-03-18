module Api
  module Support
    class LicensesController < BaseController
      def show
        license = find_license!(params[:reference])
        render json: {
          license: entitlement_payload(license, instance_id: params[:instance_id]),
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
          activations: entitlement_payload(license, instance_id: params[:instance_id])[:instances]
        }
      end

      def release
        license = find_license!(params[:reference])
        activation = if params[:device_id].present?
          license.device_activations.active.find_by!(public_id: params[:device_id])
        elsif params[:instance_record_id].present?
          license.device_activations.active.find_by!(public_id: params[:instance_record_id])
        elsif params[:instance_id].present?
          license.device_activations.active.find_by!(creem_instance_id: params[:instance_id])
        elsif params[:instance_name].present?
          license.device_activations.active.find_by!(instance_name: params[:instance_name])
        else
          raise ApiError.new("instance_id, instance_name, or instance_record_id is required", status: :bad_request, code: "missing_release_target")
        end

        if license.license_key.present? && activation.creem_instance_id.present?
          license = Licenses::DeactivationService.new.call(
            license_key: license.license_key,
            instance_id: activation.creem_instance_id,
            device_activation: activation
          )
        else
          activation.deactivate!
          license.update!(
            current_activations_count: [ license.current_activations_count - 1, 0 ].max,
            status: license.current_activations_count <= 1 ? :inactive : license.status
          )
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
