require "test_helper"

class Creem::PayloadExtractorTest < ActiveSupport::TestCase
  test "extracts normalized attributes from a nested payload" do
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

    attributes = Creem::PayloadExtractor.attributes(payload)

    assert_equal "chk_123", attributes[:creem_checkout_id]
    assert_equal "req_123", attributes[:creem_request_id]
    assert_equal "ord_123", attributes[:creem_order_id]
    assert_equal "lic_123", attributes[:creem_license_id]
    assert_equal "AAAAA-BBBBB-CCCCC-DDDDD-EEEEE", attributes[:license_key]
    assert_equal "user@example.com", attributes[:customer_email]
    assert_equal 3, attributes[:max_activations]
    assert_equal "active", attributes[:status]
    assert_equal [ "prod_respite_team" ], attributes[:product_ids]
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
