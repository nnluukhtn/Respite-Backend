class ClaimToken < ApplicationRecord
  belongs_to :license, optional: true
  belongs_to :checkout_session, optional: true

  validates :token_digest, presence: true
  validates :expires_at, presence: true

  scope :redeemable, -> { where(consumed_at: nil).where("expires_at > ?", Time.current) }

  def self.digest_for(token)
    secret = Rails.application.secret_key_base
    OpenSSL::HMAC.hexdigest("SHA256", secret, token.to_s)
  end

  def self.issue!(license: nil, checkout_session: nil, expires_in: 30.minutes, purpose: "checkout_return", metadata: {})
    raw_token = SecureRandom.urlsafe_base64(32)
    record = create!(
      license:,
      checkout_session:,
      purpose:,
      token_digest: digest_for(raw_token),
      expires_at: Time.current + expires_in,
      metadata:
    )

    [ record, raw_token ]
  end

  def expired?
    expires_at <= Time.current
  end

  def consumed?
    consumed_at.present?
  end

  def redeemable?
    !consumed? && !expired?
  end

  def consume!
    update!(consumed_at: Time.current)
  end
end
