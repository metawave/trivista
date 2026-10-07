require "test_helper"

class ScanDiffTest < ActiveSupport::TestCase
  setup do
    @branch = branches(:shop_backend_main)
    @image = artifacts(:shop_image)
    scans(:shop_main_first).update!(created_at: 10.days.ago)
  end

  test "predecessor is the latest earlier scan of the same branch and artifact" do
    earlier = scan(at: 3.days.ago)
    scan(at: 2.days.ago, artifact: projects(:shop).artifacts.create!(category: "source", name: "."))
    scan(at: 2.days.ago, branch: repos(:shop_backend).branches.create!(name: "feature"))
    current = scan(at: 1.day.ago)

    assert_equal earlier, current.predecessor
  end

  test "scans uploaded at the same time are ordered by id" do
    at = 1.day.ago
    first = scan(at:)
    second = scan(at:)

    assert_equal first, second.predecessor
  end

  test "predecessor is determined again after a scan is deleted" do
    oldest = scans(:shop_main_first)
    middle = scan(at: 2.days.ago)
    current = scan(at: 1.day.ago)

    middle.destroy!

    assert_equal oldest, current.reload.predecessor
  end

  test "reports new and no longer reported findings" do
    stays = finding("CVE-1")
    fixed = finding("CVE-2")
    added = finding("CVE-3")
    previous = scan(at: 2.days.ago, findings: [ stays, fixed ])
    current = scan(at: 1.day.ago, findings: [ stays, added ])

    diff = ScanDiff.new(current)

    assert_equal previous, diff.predecessor
    assert_equal [ added.id ], diff.new_finding_ids
    assert_equal [ fixed.id ], diff.no_longer_reported_finding_ids
  end

  test "everything is new without a predecessor" do
    scans(:shop_main_first).destroy!
    only = scan(at: 1.day.ago, findings: [ finding("CVE-1") ])

    diff = ScanDiff.new(only)

    assert_nil diff.predecessor
    assert_equal only.occurrences.pluck(:finding_id), diff.new_finding_ids
    assert_empty diff.no_longer_reported_finding_ids
  end

  private
    def scan(at:, branch: @branch, artifact: @image, findings: [])
      Scan.create!(branch:, artifact:, service_account: service_accounts(:shop_ci), commit_sha: "c0ffee",
        reported_artifact_type: "container_image", reported_artifact_name: artifact.name, created_at: at).tap do |scan|
        findings.each { scan.occurrences.create!(finding: it, severity: "HIGH", installed_version: "1.0") }
      end
    end

    def finding(identifier)
      projects(:shop).findings.create!(finding_type: "vulnerability", identifier:, pkg_name: "pkg",
        fingerprint: Digest::SHA256.hexdigest(identifier))
    end
end
