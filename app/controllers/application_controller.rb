class ApplicationController < ActionController::API
  rescue_from ApiError, with: :render_api_error
  rescue_from ActionController::ParameterMissing do |error|
    render_api_error(ApiError.new(error.message, status: :bad_request, code: "missing_parameter"))
  end
  rescue_from ActiveRecord::RecordNotFound do |error|
    render_api_error(ApiError.new(error.message, status: :not_found, code: "not_found"))
  end
  rescue_from ActiveRecord::RecordInvalid do |error|
    render_api_error(
      ApiError.new(
        error.record.errors.full_messages.to_sentence,
        status: :unprocessable_entity,
        code: "validation_failed",
        details: error.record.errors.to_hash(true)
      )
    )
  end

  private

  def render_api_error(error)
    render json: {
      error: {
        code: error.code,
        message: error.message,
        details: error.details
      }
    }, status: error.status
  end

  def entitlement_payload(license, instance_id: nil)
    EntitlementPayloadPresenter.new(
      license:,
      instance_id:
    ).as_json
  end
end
