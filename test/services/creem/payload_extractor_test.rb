require "test_helper"

class Creem::PayloadExtractorTest < ActiveSupport::TestCase
  test "extracts normalized attributes from a Creem desktop-license payload" do
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

    attributes = Creem::PayloadExtractor.attributes(payload)

    assert_equal "chk_123", attributes[:creem_checkout_id]
    assert_equal "req_123", attributes[:creem_request_id]
    assert_equal "ord_123", attributes[:creem_order_id]
    assert_equal "lic_123", attributes[:creem_license_id]
    assert_equal "cus_123", attributes[:creem_customer_id]
    assert_equal "AAAAA-BBBBB-CCCCC-DDDDD-EEEEE", attributes[:license_key]
    assert_equal "inst_123", attributes[:instance_id]
    assert_equal "MacBook Pro", attributes[:instance_name]
    assert_equal "active", attributes[:instance_status]
    assert_equal "user@example.com", attributes[:customer_email]
    assert_equal 3, attributes[:max_activations]
    assert_equal 1, attributes[:current_activations]
    assert_equal "2026-12-31T00:00:00Z", attributes[:expires_at]
    assert_equal "active", attributes[:status]
    assert_equal [ "prod_respite_ultimate" ], attributes[:product_ids]
    assert_equal 3, attributes[:units]
  end

  test "creates a deterministic event id fallback when no explicit event id is present" do
    payload = {
      "event" => {
        "type" => "refund.created"
      },
      "checkout" => {
        "id" => "chk_123"
      }
    }

    event_id = Creem::PayloadExtractor.event_id(payload)

    assert event_id.present?
    assert_equal event_id, Creem::PayloadExtractor.event_id(payload)
    refute_equal "chk_123", event_id
  end
end
