require "test_helper"

class RetentionTest < ActiveSupport::TestCase
  setup do
    @branch = branches(:shop_backend_main)
    @image = artifacts(:shop_image)
    @owner = owners(:team_a)
    scans(:shop_main_first).destroy!
    Owner.where(id: @owner.id).update_all(occurrence_count: 0)
  end

  test "removes the occurrences of expired scans and keeps their counts" do
    expired = scan(at: 100.days.ago, findings: [ finding("CVE-1"), finding("CVE-2") ])
    scan(at: 1.day.ago, findings: [ finding("CVE-2") ])

    Retention.new(days: 90).call

    assert_empty expired.occurrences.reload
    assert expired.reload.occurrences_pruned_at
    assert_equal({ "vulnerability" => { "HIGH" => 2 } }, expired.counts)
  end

  test "lowers the owner quota by the removed occurrences" do
    scan(at: 100.days.ago, findings: [ finding("CVE-1"), finding("CVE-2") ])
    scan(at: 1.day.ago, findings: [ finding("CVE-2") ])

    Retention.new(days: 90).call

    assert_equal 1, @owner.reload.occurrence_count
  end

  test "removes findings without remaining occurrences" do
    gone = finding("CVE-1")
    kept = finding("CVE-2")
    scan(at: 100.days.ago, findings: [ gone, kept ])
    scan(at: 1.day.ago, findings: [ kept ])

    Retention.new(days: 90).call

    assert_not Finding.exists?(gone.id)
    assert Finding.exists?(kept.id)
  end

  test "keeps the latest scan of a branch and artifact however old it is" do
    older = scan(at: 200.days.ago, findings: [ finding("CVE-1") ])
    latest = scan(at: 100.days.ago, findings: [ finding("CVE-2") ])

    Retention.new(days: 90).call

    assert_empty older.occurrences.reload
    assert_equal 1, latest.occurrences.count
    assert_nil latest.reload.occurrences_pruned_at
  end

  test "keeps scans within the retention period" do
    recent = scan(at: 89.days.ago, findings: [ finding("CVE-1") ])
    scan(at: 1.day.ago, findings: [ finding("CVE-2") ])

    Retention.new(days: 90).call

    assert_equal 1, recent.occurrences.count
  end

  test "zero days turns retention off" do
    expired = scan(at: 400.days.ago, findings: [ finding("CVE-1") ])
    scan(at: 1.day.ago, findings: [ finding("CVE-2") ])

    Retention.new(days: 0).call

    assert_equal 1, expired.occurrences.count
  end

  test "a second run leaves pruned scans alone" do
    expired = scan(at: 100.days.ago, findings: [ finding("CVE-1") ])
    scan(at: 1.day.ago, findings: [ finding("CVE-2") ])
    Retention.new(days: 90).call

    assert_no_changes -> { [ @owner.reload.occurrence_count, expired.reload.occurrences_pruned_at ] } do
      travel(1.day) { Retention.new(days: 90).call }
    end
  end

  test "a diff is not available when the predecessor's details are gone" do
    stays = finding("CVE-1")
    scan(at: 100.days.ago, findings: [ stays, finding("CVE-2") ])
    current = scan(at: 1.day.ago, findings: [ stays ])

    Retention.new(days: 90).call
    diff = ScanDiff.new(current)

    assert_not diff.available?
    assert_empty diff.new_finding_ids
    assert_empty diff.no_longer_reported_finding_ids
  end

  test "a diff is not available when the scan's own details are gone" do
    predecessor = scan(at: 3.days.ago, findings: [ finding("CVE-1") ])
    current = scan(at: 2.days.ago)
    current.update_columns(occurrences_pruned_at: Time.current)

    diff = ScanDiff.new(current)

    assert_equal predecessor, diff.predecessor
    assert_empty diff.no_longer_reported_finding_ids
  end

  private
    def scan(at:, findings: [])
      Scan.create!(branch: @branch, artifact: @image, service_account: service_accounts(:shop_ci), commit_sha: "c0ffee",
        reported_artifact_type: "container_image", reported_artifact_name: @image.name, created_at: at,
        counts: { "vulnerability" => { "HIGH" => findings.size } }).tap do |scan|
        findings.each { scan.occurrences.create!(finding: it, severity: "HIGH", installed_version: "1.0") }
        Owner.where(id: @owner.id).update_all([ "occurrence_count = occurrence_count + ?", findings.size ])
      end
    end

    def finding(identifier)
      projects(:shop).findings.find_or_create_by!(fingerprint: Digest::SHA256.hexdigest(identifier)) do |finding|
        finding.assign_attributes(finding_type: "vulnerability", identifier:, pkg_name: "pkg")
      end
    end
end
