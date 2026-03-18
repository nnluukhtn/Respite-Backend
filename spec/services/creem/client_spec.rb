require "spec_helper"
require "ostruct"

RSpec.describe Creem::Client do
  let(:http) { instance_double(Net::HTTP) }
  let(:response) { instance_double(Net::HTTPOK, body: response_body) }
  let(:response_body) { '{"id":"chk_123","checkout_url":"https://checkout.example.com"}' }
  let(:captured_requests) { [] }

  before do
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:read_timeout=)
    allow(http).to receive(:open_timeout=)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    allow(http).to receive(:request) do |request|
      captured_requests << request
      response
    end
  end

  it "creates checkouts with x-api-key auth and units" do
    client = described_class.new(api_base_url: "https://api.creem.io/v1", api_key: "creem_test")
    checkout_session = OpenStruct.new(public_id: "req_123", variant_key: "enterprise")
    variant = OpenStruct.new(creem_product_id: "prod_enterprise")

    client.create_checkout(
      variant:,
      checkout_session:,
      customer_email: "user@example.com",
      units: 7
    )

    request = captured_requests.last
    expect(request["x-api-key"]).to eq("creem_test")
    expect(JSON.parse(request.body)).to include(
      "product_id" => "prod_enterprise",
      "request_id" => "req_123",
      "units" => 7
    )
  end

  it "activates licenses with key and instance_name" do
    client = described_class.new(api_base_url: "https://api.creem.io/v1", api_key: "creem_test")

    client.activate_license(
      license_key: "AAAAA-BBBBB-CCCCC-DDDDD-EEEEE",
      instance_name: "MacBook Pro"
    )

    request = captured_requests.last
    expect(JSON.parse(request.body)).to eq(
      "key" => "AAAAA-BBBBB-CCCCC-DDDDD-EEEEE",
      "instance_name" => "MacBook Pro"
    )
  end

  it "validates and deactivates licenses with instance_id" do
    client = described_class.new(api_base_url: "https://api.creem.io/v1", api_key: "creem_test")

    client.validate_license(
      license_key: "AAAAA-BBBBB-CCCCC-DDDDD-EEEEE",
      instance_id: "inst_123"
    )
    validate_request = captured_requests.last
    expect(JSON.parse(validate_request.body)).to eq(
      "key" => "AAAAA-BBBBB-CCCCC-DDDDD-EEEEE",
      "instance_id" => "inst_123"
    )

    client.deactivate_license(
      license_key: "AAAAA-BBBBB-CCCCC-DDDDD-EEEEE",
      instance_id: "inst_123"
    )
    deactivate_request = captured_requests.last
    expect(JSON.parse(deactivate_request.body)).to eq(
      "key" => "AAAAA-BBBBB-CCCCC-DDDDD-EEEEE",
      "instance_id" => "inst_123"
    )
  end
end
