require "test_helper"

class ScanFindingsTest < ActiveSupport::TestCase
  test "groups findings across several scans and keeps the scans they occur in" do
    image_scan = scans(:shop_main_first)
    source_scan = Scan.create!(branch: image_scan.branch, artifact: projects(:shop).artifacts.create!(category: "source", name: "."),
      service_account: image_scan.service_account, commit_sha: "c0ffee", reported_artifact_type: "filesystem", reported_artifact_name: ".")
    shared = finding("CVE-2024-0001")
    only_source = finding("CVE-2024-0002")
    image_scan.occurrences.create!(finding: shared, severity: "LOW")
    source_scan.occurrences.create!(finding: shared, severity: "HIGH")
    source_scan.occurrences.create!(finding: only_source, severity: "MEDIUM")

    rows = ScanFindings.new([ image_scan, source_scan ]).page(limit: 10, finding_type: "vulnerability").rows.index_by(&:finding)

    assert_equal "HIGH", rows.fetch(shared).severity
    assert_equal [ image_scan.id, source_scan.id ].sort, rows.fetch(shared).scan_ids.sort
    assert_equal [ source_scan.id ], rows.fetch(only_source).scan_ids
  end

  private
    def finding(identifier)
      projects(:shop).findings.create!(finding_type: "vulnerability", identifier:, fingerprint: Digest::SHA256.hexdigest(identifier))
    end
end
