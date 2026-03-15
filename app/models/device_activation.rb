class DeviceActivation < ApplicationRecord
  belongs_to :license

  scope :active, -> { where(deactivated_at: nil) }

  validates :device_fingerprint, presence: true
  validates :device_name, presence: true
  validates :activated_at, presence: true
  validate :single_active_record_per_device, if: -> { deactivated_at.nil? }

  before_validation :normalize_fields
  after_commit :refresh_license_activation_count

  def active?
    deactivated_at.nil?
  end

  def deactivate!(timestamp: Time.current)
    update!(deactivated_at: timestamp) if active?
  end

  private

  def normalize_fields
    self.device_fingerprint = device_fingerprint.to_s.strip.presence
    self.device_name = device_name.to_s.strip.presence || "Unknown device"
  end

  def single_active_record_per_device
    scope = self.class.active.where(license_id:, device_fingerprint:)
    scope = scope.where.not(id:) if persisted?
    return unless scope.exists?

    errors.add(:device_fingerprint, "is already active for this license")
  end

  def refresh_license_activation_count
    return unless license_id

    License.where(id: license_id).update_all(
      current_activations_count: DeviceActivation.active.where(license_id:).count
    )
  end
end
