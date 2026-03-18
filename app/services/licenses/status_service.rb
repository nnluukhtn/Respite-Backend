module Licenses
  class StatusService
    def initialize(synchronizer: Licenses::Synchronizer.new)
      @synchronizer = synchronizer
    end

    def call(license_key:, instance_id:, refresh: true)
      synchronizer.ensure_from_credentials!(
        license_key:,
        instance_id:,
        refresh:
      )
    end

    private

    attr_reader :synchronizer
  end
end
