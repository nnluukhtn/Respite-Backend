module Api
  module Pro
    class LicensesController < ApplicationController
      def activate
        license = Licenses::ActivationService.new.call(
          customer_email: params.require(:email),
          license_key: params.require(:license_key),
          device_fingerprint: params.require(:device_fingerprint),
          device_name: params.require(:device_name)
        )

        render json: {
          entitlement: entitlement_payload(
            license,
            device_fingerprint: params[:device_fingerprint]
          )
        }, status: :created
      end

      def status
        license = Licenses::StatusService.new.call(
          customer_email: params.require(:email),
          license_key: params.require(:license_key),
          refresh: ActiveModel::Type::Boolean.new.cast(params.fetch(:refresh, true))
        )

        render json: {
          entitlement: entitlement_payload(
            license,
            device_fingerprint: params[:device_fingerprint]
          )
        }
      end

      def deactivate
        target_fingerprint = params[:target_device_fingerprint].presence || params[:device_fingerprint]

        license = Licenses::DeactivationService.new.call(
          customer_email: params.require(:email),
          license_key: params.require(:license_key),
          device_fingerprint: target_fingerprint,
          device_id: params[:device_id]
        )

        render json: {
          entitlement: entitlement_payload(
            license,
            device_fingerprint: params[:device_fingerprint]
          )
        }
      end
    end
  end
end
