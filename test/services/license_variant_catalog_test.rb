require "test_helper"

class LicenseVariantCatalogTest < ActiveSupport::TestCase
  test "fetches a configured variant" do
    variant = LicenseVariantCatalog.fetch!("pro")

    assert_equal "pro", variant.key
    assert_equal "single_seat", variant.license_type
    assert_equal 1, variant.max_activations
  end

  test "finds a variant by Creem product identifiers" do
    variant = LicenseVariantCatalog.find_for_product_ids(%w[offer_respite_ultimate prod_other])

    assert_equal "ultimate", variant.key
    assert_equal 3, variant.max_activations
  end

  test "supports enterprise tiers with custom capacity" do
    variant = LicenseVariantCatalog.fetch!("enterprise")

    assert_equal "enterprise", variant.key
    assert_equal "enterprise", variant.license_type
    assert_nil variant.max_activations
    assert_equal true, variant.custom_capacity
  end
end
