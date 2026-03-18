class CheckoutSession < ApplicationRecord
  belongs_to :license, optional: true
  has_many :claim_tokens, dependent: :destroy

  enum :status, {
    pending: "pending",
    completed: "completed",
    claimed: "claimed",
    expired: "expired",
    failed: "failed",
    refunded: "refunded",
    revoked: "revoked"
  }, validate: true

  validates :variant_key, presence: true

  before_validation :normalize_customer_email

  def mark_completed!(license:)
    update!(
      license:,
      status: :completed,
      completed_at: Time.current
    )
  end

  def mark_claimed!
    update!(status: :claimed, claimed_at: Time.current)
  end

  private

  def normalize_customer_email
    self.customer_email = customer_email.to_s.strip.downcase.presence
  end
end
