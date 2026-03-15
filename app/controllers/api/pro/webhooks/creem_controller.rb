module Api
  module Pro
    module Webhooks
      class CreemController < ApplicationController
        skip_before_action :verify_authenticity_token, raise: false

        def create
          raw_payload = request.raw_post
          Creem::WebhookSignatureVerifier.verify!(raw_payload:, request:)
          payload = JSON.parse(raw_payload)
          event_id = Creem::PayloadExtractor.event_id(payload)
          event_type = Creem::PayloadExtractor.event_type(payload)
          signature = Creem::WebhookSignatureVerifier.extract_signature(request)

          if VendorWebhookEvent.exists?(vendor: "creem", external_event_id: event_id)
            render json: { status: "duplicate" }
            return
          end

          event = VendorWebhookEvent.create!(
            vendor: "creem",
            external_event_id: event_id,
            event_type: event_type,
            signature:,
            payload:,
            received_at: Time.current
          )

          WebhookEventProcessor.new.process!(event)
          event.update!(processing_status: :processed, processed_at: Time.current)

          render json: { status: "ok" }
        rescue ActiveRecord::RecordNotUnique
          render json: { status: "duplicate" }
        rescue JSON::ParserError
          raise ApiError.new("Invalid JSON payload", status: :bad_request, code: "invalid_json")
        rescue StandardError => error
          if defined?(event) && event&.persisted?
            event.update!(
              processing_status: :failed,
              last_error: error.message
            )
          end
          raise
        end
      end
    end
  end
end
