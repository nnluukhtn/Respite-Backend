require "spec_helper"

RSpec.describe Creem::PayloadExtractor do
  describe ".attributes" do
    it "extracts normalized attributes from a Creem desktop-license payload" do
      payload = {
        "event" => {
          "id" => "evt_123",
          "eventType" => "checkout.completed"
        },
        "object" => {
          "id" => "chk_123",
          "request_id" => "req_123",
          "product" => {
            "id" => "prod_respite_ultimate"
          },
          "customer" => {
            "id" => "cus_123",
            "email" => "USER@EXAMPLE.COM"
          },
          "order" => {
            "id" => "ord_123"
          },
          "license_keys" => [
            {
              "id" => "lic_123",
              "key" => "AAAAA-BBBBB-CCCCC-DDDDD-EEEEE",
              "activation_limit" => 3,
              "activation_count" => 1,
              "status" => "active",
              "expires_at" => "2026-12-31T00:00:00Z",
              "instance" => {
                "id" => "inst_123",
                "name" => "MacBook Pro",
                "status" => "active"
              }
            }
          ],
          "units" => 3
        }
      }

      expect(described_class.attributes(payload)).to eq(
        creem_checkout_id: "chk_123",
        creem_request_id: "req_123",
        creem_order_id: "ord_123",
        creem_license_id: "lic_123",
        creem_customer_id: "cus_123",
        license_key: "AAAAA-BBBBB-CCCCC-DDDDD-EEEEE",
        instance_id: "inst_123",
        instance_name: "MacBook Pro",
        instance_status: "active",
        customer_email: "user@example.com",
        max_activations: 3,
        current_activations: 1,
        expires_at: "2026-12-31T00:00:00Z",
        status: "active",
        product_ids: [ "prod_respite_ultimate" ],
        units: 3
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
