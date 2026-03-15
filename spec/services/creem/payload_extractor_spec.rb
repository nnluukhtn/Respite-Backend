require "spec_helper"

RSpec.describe Creem::PayloadExtractor do
  describe ".attributes" do
    it "extracts normalized attributes from a nested payload" do
      payload = {
        "event" => {
          "id" => "evt_123",
          "type" => "checkout.completed"
        },
        "license" => {
          "license_id" => "lic_123",
          "license_key" => "AAAAA-BBBBB-CCCCC-DDDDD-EEEEE",
          "max_activations" => 3,
          "status" => "valid"
        },
        "order" => {
          "id" => "ord_123",
          "email" => "USER@EXAMPLE.COM"
        },
        "checkout" => {
          "id" => "chk_123",
          "request_id" => "req_123"
        },
        "product_id" => "prod_respite_team"
      }

      expect(described_class.attributes(payload)).to eq(
        creem_checkout_id: "chk_123",
        creem_request_id: "req_123",
        creem_order_id: "ord_123",
        creem_license_id: "lic_123",
        license_key: "AAAAA-BBBBB-CCCCC-DDDDD-EEEEE",
        activation_id: nil,
        customer_email: "user@example.com",
        max_activations: 3,
        status: "active",
        product_ids: [ "prod_respite_team" ]
      )
    end
  end

  describe ".event_id" do
    it "creates a deterministic fallback id when the event is unnamed" do
      payload = {
        "event" => {
          "type" => "refund.created"
        },
        "checkout" => {
          "id" => "chk_123"
        }
      }

      event_id = described_class.event_id(payload)

      expect(event_id).to be_present
      expect(described_class.event_id(payload)).to eq(event_id)
      expect(event_id).not_to eq("chk_123")
    end
  end
end
