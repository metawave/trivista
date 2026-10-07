require "test_helper"

class OccurrenceTest < ActiveSupport::TestCase
  test "occurrence is unique per scan, finding, version and location, treating missing values as equal" do
    duplicate = Occurrence.new(scan: scans(:shop_main_first), finding: findings(:openssl_cve),
      installed_version: "3.0.1", severity: "HIGH")

    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "another installed version of the same finding is a separate occurrence" do
    assert Occurrence.create!(scan: scans(:shop_main_first), finding: findings(:openssl_cve),
      installed_version: "3.0.2", severity: "HIGH")
  end

  test "severity is restricted to Trivy severities" do
    assert_raises(ActiveRecord::StatementInvalid) { occurrences(:openssl_in_first).update_column(:severity, "SEVERE") }
  end
end
