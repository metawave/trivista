require "test_helper"

class ScanDetailTest < ActionDispatch::IntegrationTest
  setup do
    @scan = scans(:shop_main_first)
    @scan.update!(created_at: 1.day.ago)
    @critical = finding("CVE-2024-1111", primary_url: "https://avd.example.com/CVE-2024-1111")
    @unsafe = finding("CVE-2024-2222", primary_url: "javascript:alert(document.cookie)")
    @secret = projects(:shop).findings.create!(finding_type: "secret", identifier: "aws-secret-access-key",
      title: "AWS Secret Access Key", target: "config/settings.env", fingerprint: Digest::SHA256.hexdigest("secret"))
    @scan.occurrences.create!(finding: @critical, severity: "CRITICAL", installed_version: "1.0", fixed_version: "1.1")
    @scan.occurrences.create!(finding: @critical, severity: "LOW", installed_version: "2.0")
    @scan.occurrences.create!(finding: @unsafe, severity: "MEDIUM", installed_version: "1.0")
    @scan.occurrences.create!(finding: @secret, severity: "CRITICAL", start_line: 3)
    sign_in(sub: "dave-sub")
  end

  test "shows scan metadata and the uploading service account" do
    get scan_path(@scan)

    assert_response :success
    assert_select "dd", text: /\Aci\s+team-a\z/
    assert_select "dd", text: /\A\s*#{@scan.commit_sha}\s*\z/
  end

  test "lists one row per finding with the highest severity and all versions" do
    get scan_path(@scan)

    assert_select "tr#finding_#{@critical.id}" do
      assert_select "td.severity", text: "CRITICAL"
      assert_select "td.versions", text: /1\.0.*2\.0/m
      assert_select "td.fixed", text: "1.1"
    end
  end

  test "links only http urls" do
    get scan_path(@scan)

    assert_select "a[href=?]", "https://avd.example.com/CVE-2024-1111", text: "CVE-2024-1111"
    assert_select "a[href^=javascript]", count: 0
    assert_select "tr#finding_#{@unsafe.id} td.identifier", text: "CVE-2024-2222"
  end

  test "filters by finding type and severity" do
    get scan_path(@scan, type: "secret")
    assert_select "tbody.current tr", 1

    get scan_path(@scan, severity: "MEDIUM")
    assert_select "tbody.current tr", 1
    assert_select "tr#finding_#{@unsafe.id}"
  end

  test "marks new findings and can show only those" do
    previous = Scan.create!(branch: @scan.branch, artifact: @scan.artifact, service_account: @scan.service_account,
      commit_sha: "0ld", reported_artifact_type: "container_image", reported_artifact_name: "x", created_at: 2.days.ago)
    previous.occurrences.create!(finding: @critical, severity: "CRITICAL", installed_version: "1.0")
    gone = finding("CVE-2024-3333")
    previous.occurrences.create!(finding: gone, severity: "HIGH", installed_version: "1.0")

    get scan_path(@scan, only_new: "1")

    assert_select "tbody.current tr#finding_#{@unsafe.id} .marker", text: "NEW"
    assert_select "tr#finding_#{@critical.id}", 0
    assert_select "tbody.no-longer-reported tr#finding_#{gone.id}"

    get scan_path(@scan, only_new: "1", type: "secret")
    assert_select "tbody.current tr#finding_#{@secret.id}"
    assert_select "#no-longer-reported", text: /Secrets not reported.*\(1 across all types\)/m
    assert_select "#no-longer-reported .empty", text: "None with these filters."
    assert_select ".diff-summary a[href='#no-longer-reported']", text: /−1/
    assert_select ".diff-summary a[href=?]", scan_path(@scan, type: "secret", only_new: "1"), text: /\+3/
  end

  test "shows one tab per finding type and opens the first type with findings" do
    @scan.update!(counts: { "secret" => { "CRITICAL" => 1 }, "license" => { "LOW" => 2, "HIGH" => 1 } })

    get scan_path(@scan)

    assert_select ".tab[aria-current=page]", text: /Secrets\s*1/
    assert_select ".tab", text: /Licenses\s*3/
    assert_select "tbody.current tr#finding_#{@secret.id}"
  end

  test "severity chips filter by several severities and toggle one at a time" do
    get scan_path(@scan, severity: "MEDIUM,CRITICAL,bogus")

    assert_select "tbody.current tr", 2
    assert_select ".toggle[aria-current=true]", text: /CRITICAL/
    assert_select ".toggle[aria-current=false]", text: /HIGH/
    assert_select "a.toggle[href=?]", scan_path(@scan, type: "vulnerability", severity: "CRITICAL,HIGH,MEDIUM")
    assert_select "a.toggle[href=?]", scan_path(@scan, type: "vulnerability", severity: "CRITICAL")
  end

  private
    def finding(identifier, primary_url: nil)
      projects(:shop).findings.create!(finding_type: "vulnerability", identifier:, pkg_name: "openssl", primary_url:,
        title: "#{identifier} flaw", fingerprint: Digest::SHA256.hexdigest(identifier))
    end
end
