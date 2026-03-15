module Api
  module Pro
    class CheckoutSessionsController < ApplicationController
      def create
        variant = LicenseVariantCatalog.fetch!(params.require(:variant))
        checkout_session = CheckoutSession.create!(
          variant_key: variant.key,
          customer_email: params[:customer_email],
          creem_product_id: variant.creem_product_id,
          status: :pending
        )

        response = Creem::Client.new.create_checkout(
          variant:,
          checkout_session:,
          customer_email: checkout_session.customer_email,
          success_url: params[:success_url],
          cancel_url: params[:cancel_url]
        )

        checkout_session.update!(
          creem_checkout_id: response[:checkout_id],
          creem_request_id: response[:request_id],
          hosted_checkout_url: response[:checkout_url],
          expires_at: response[:expires_at],
          metadata: checkout_session.metadata.merge("create_checkout_response" => response[:raw])
        )

        render json: {
          checkout_session_id: checkout_session.public_id,
          checkout_url: checkout_session.hosted_checkout_url
        }, status: :created
      rescue Creem::Error => error
        checkout_session&.update!(status: :failed, last_error: error.message) if defined?(checkout_session) && checkout_session&.persisted?
        raise
      end
    end
  end
end
