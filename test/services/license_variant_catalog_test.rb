require "test_helper"

class LicenseVariantCatalogTest < ActiveSupport::TestCase
  test "fetches a configured variant" do
    variant = LicenseVariantCatalog.fetch!("solo")

    assert_equal "solo", variant.key
    assert_equal "single_seat", variant.license_type
    assert_equal 1, variant.max_activations
  end

  test "finds a variant by Creem product identifiers" do
    variant = LicenseVariantCatalog.find_for_product_ids(%w[offer_respite_team prod_other])

    assert_equal "team", variant.key
    assert_equal 5, variant.max_activations
  end
end
