module Licenses
  class StatusService
    def initialize(synchronizer: Licenses::Synchronizer.new)
      @synchronizer = synchronizer
    end

    def call(customer_email:, license_key:, refresh: true)
      synchronizer.ensure_from_credentials!(
        customer_email:,
        license_key:,
        refresh:
      )
    end

    private

    attr_reader :synchronizer
  end
end
