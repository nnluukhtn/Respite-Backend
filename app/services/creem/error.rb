module Creem
  class Error < ApiError
    attr_reader :http_status, :response_body

    def initialize(message, code: "creem_error", status: :bad_gateway, http_status: nil, response_body: nil)
      super(message, status:, code:, details: response_body)
      @http_status = http_status
      @response_body = response_body
    end
  end
end
