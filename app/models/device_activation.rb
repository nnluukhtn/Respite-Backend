class DeviceActivation < ApplicationRecord
  belongs_to :license

  scope :active, -> { where(deactivated_at: nil) }

  validates :instance_name, presence: true
  validates :activated_at, presence: true
  validate :single_active_record_per_device, if: -> { deactivated_at.nil? }

  before_validation :normalize_fields

  def active?
    deactivated_at.nil?
  end

  def deactivate!(timestamp: Time.current)
    update!(deactivated_at: timestamp, instance_status: "inactive") if active?
  end

  private

  def normalize_fields
    self.instance_name = instance_name.to_s.strip.presence || "Unknown instance"
    self.creem_instance_id = creem_instance_id.to_s.strip.presence
    self.instance_status = instance_status.to_s.strip.presence || (deactivated_at.nil? ? "active" : "inactive")
  end

  def single_active_record_per_device
    scope = self.class.active.where(license_id:)
    scope = scope.where.not(id:) if persisted?
    scope = if creem_instance_id.present?
      scope.where(creem_instance_id:)
    else
      scope.where(instance_name:)
    end
    return unless scope.exists?

    errors.add(:base, "instance is already active for this license")
  end
end
