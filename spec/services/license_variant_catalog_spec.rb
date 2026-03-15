require "spec_helper"

RSpec.describe LicenseVariantCatalog do
  describe ".fetch!" do
    it "returns a configured variant" do
      variant = described_class.fetch!("solo")

      expect(variant.key).to eq("solo")
      expect(variant.license_type).to eq("single_seat")
      expect(variant.max_activations).to eq(1)
    end
  end

  describe ".find_for_product_ids" do
    it "matches a variant by Creem offer or product id" do
      variant = described_class.find_for_product_ids(%w[offer_respite_team prod_other])

      expect(variant.key).to eq("team")
      expect(variant.max_activations).to eq(5)
    end
  end
end
