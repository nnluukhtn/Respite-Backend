class VendorWebhookEvent < ApplicationRecord
  enum :processing_status, {
    received: "received",
    processed: "processed",
    failed: "failed",
    duplicate: "duplicate"
  }, validate: true

  validates :vendor, presence: true
  validates :external_event_id, presence: true
  validates :received_at, presence: true
end
