module Api
  module Pro
    class LicensesController < ApplicationController
      def activate
        license = Licenses::ActivationService.new.call(
          license_key: params.require(:license_key),
          instance_name: params[:instance_name].presence || params[:device_name].presence || params.require(:instance_name)
        )

        render json: {
          entitlement: entitlement_payload(
            license,
            instance_id: license.device_activations.active.order(activated_at: :desc).first&.creem_instance_id
          )
        }, status: :created
      end

      def status
        license = Licenses::StatusService.new.call(
          license_key: params.require(:license_key),
          instance_id: params.require(:instance_id),
          refresh: ActiveModel::Type::Boolean.new.cast(params.fetch(:refresh, true))
        )

        render json: {
          entitlement: entitlement_payload(
            license,
            instance_id: params[:instance_id]
          )
        }
      end

      def deactivate
        license = Licenses::DeactivationService.new.call(
          license_key: params.require(:license_key),
          instance_id: params[:target_instance_id].presence || params[:instance_id],
          activation_record_id: params[:instance_record_id].presence || params[:device_id]
        )

        render json: {
          entitlement: entitlement_payload(
            license,
            instance_id: params[:instance_id]
          )
        }
      end
    end
  end
end
