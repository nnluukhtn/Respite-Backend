class License < ApplicationRecord
  encrypts :license_key

  has_many :device_activations, dependent: :destroy
  has_many :claim_tokens, dependent: :destroy
  has_many :checkout_sessions, dependent: :nullify

  enum :license_type, {
    single_seat: "single_seat",
    multi_seat: "multi_seat",
    enterprise: "enterprise"
  }, prefix: true, validate: true

  enum :status, {
    pending: "pending",
    active: "active",
    inactive: "inactive",
    revoked: "revoked",
    refunded: "refunded"
  }, validate: true

  validates :license_type, presence: true
  validates :max_activations, numericality: { greater_than: 0 }

  before_validation :normalize_customer_email
  before_validation :sync_license_key_metadata

  scope :entitled, -> { where(status: %w[pending active inactive]) }

  def self.digest_for(raw_license_key)
    normalized_key = raw_license_key.to_s.upcase.gsub(/[^A-Z0-9]/, "")
    return if normalized_key.blank?

    secret = Rails.application.secret_key_base
    OpenSSL::HMAC.hexdigest("SHA256", secret, normalized_key)
  end

  def active_device_activations
    device_activations.active.order(activated_at: :asc)
  end

  def current_activations
    active_device_activations.count
  end

  def active_for_device?(device_fingerprint)
    return false if device_fingerprint.blank?

    active_device_activations.exists?(device_fingerprint: device_fingerprint)
  end

  def seats_available
    [ max_activations - current_activations_count, 0 ].max
  end

  def revocable?
    active? || inactive? || pending?
  end

  private

  def normalize_customer_email
    self.customer_email = customer_email.to_s.strip.downcase.presence
  end

  def sync_license_key_metadata
    return if license_key.blank?

    normalized_key = license_key.upcase.gsub(/[^A-Z0-9]/, "")
    self.license_key_digest = self.class.digest_for(normalized_key)
    self.license_key_last4 = normalized_key.last(4)
  end
end
