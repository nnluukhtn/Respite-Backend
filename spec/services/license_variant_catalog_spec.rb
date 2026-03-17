require "spec_helper"

RSpec.describe LicenseVariantCatalog do
  describe ".fetch!" do
    it "returns a configured variant" do
      variant = described_class.fetch!("pro")

      expect(variant.key).to eq("pro")
      expect(variant.license_type).to eq("single_seat")
      expect(variant.max_activations).to eq(1)
    end
  end

  describe ".find_for_product_ids" do
    it "matches a variant by Creem offer or product id" do
      variant = described_class.find_for_product_ids(%w[offer_respite_ultimate prod_other])

      expect(variant.key).to eq("ultimate")
      expect(variant.max_activations).to eq(3)
    end
  end

  describe ".fetch!" do
    it "marks enterprise as custom capacity" do
      variant = described_class.fetch!("enterprise")

      expect(variant.key).to eq("enterprise")
      expect(variant.license_type).to eq("enterprise")
      expect(variant.max_activations).to be_nil
      expect(variant.custom_capacity).to be(true)
    end
  end
end
