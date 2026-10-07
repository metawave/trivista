require "test_helper"

class FindingTest < ActiveSupport::TestCase
  test "fingerprint is unique per project" do
    duplicate = Finding.new(project: projects(:shop), finding_type: "vulnerability",
      fingerprint: findings(:openssl_cve).fingerprint, identifier: "CVE-2024-0001")

    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "same fingerprint is allowed in another project" do
    assert Finding.create!(project: projects(:alice_tools), finding_type: "vulnerability",
      fingerprint: findings(:openssl_cve).fingerprint, identifier: "CVE-2024-0001")
  end

  test "finding type is restricted to the four Trivy types" do
    assert_raises(ActiveRecord::StatementInvalid) { findings(:openssl_cve).update_column(:finding_type, "package") }
  end
end
