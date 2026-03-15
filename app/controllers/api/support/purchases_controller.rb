module Api
  module Support
    class PurchasesController < BaseController
      def resync
        checkout_session = locate_checkout_session!
        raise ApiError.new("checkout_session_id or creem_checkout_id is required", status: :bad_request, code: "missing_resync_reference") unless checkout_session
        raise ApiError.new("Checkout session is missing a Creem checkout id", status: :conflict, code: "missing_creem_checkout_id") if checkout_session.creem_checkout_id.blank?

        license = Licenses::Synchronizer.new.sync_checkout!(
          checkout_id: checkout_session.creem_checkout_id,
          checkout_session:
        )

        render json: {
          checkout_session_id: checkout_session.public_id,
          entitlement: entitlement_payload(license)
        }
      end

      private

      def locate_checkout_session!
        if params[:checkout_session_id].present?
          CheckoutSession.find_by(public_id: params[:checkout_session_id]) ||
            CheckoutSession.find_by(creem_request_id: params[:checkout_session_id])
        elsif params[:creem_checkout_id].present?
          CheckoutSession.find_by(creem_checkout_id: params[:creem_checkout_id])
        elsif params[:creem_order_id].present?
          CheckoutSession.joins(:license).find_by(licenses: { creem_order_id: params[:creem_order_id] })
        end
      end
    end
  end
end
