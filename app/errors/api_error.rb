class ApiError < StandardError
  attr_reader :status, :code, :details

  def initialize(message, status: :unprocessable_entity, code: "unprocessable_entity", details: nil)
    super(message)
    @status = status
    @code = code
    @details = details
  end
end
