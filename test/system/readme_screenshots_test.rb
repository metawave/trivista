require "application_system_test_case"

# Renders the README screenshots in docs/screenshots from demo data; run with bin/screenshots.
class ReadmeScreenshotsTest < ApplicationSystemTestCase
  DIRECTORY = Rails.root.join("docs/screenshots")

  setup do
    travel_to Time.zone.local(2026, 10, 8, 9, 0)
    Project.find_each { Purge.new(it).call }
    @project = seed_demo_project
    sign_in
  end

  test "readme screenshots" do
    repo = @project.repos.find_by!(name: "platform-api")

    capture "projects", root_path
    capture "project", project_path(@project), chart: true
    capture "repo", repo_path(repo)
    capture "repo-scans", repo_path(repo, view: "scans"), chart: true
    capture "scan", scan_path(repo.default_branch.scans.order(:created_at).last)
  end

  private
    def capture(name, path, chart: false)
      visit path
      assert_selector "main"
      sleep 1.5 if chart # ponytail: waits out the Chart.js animation; disable animations if screenshots get flaky
      page.save_screenshot(DIRECTORY.join("#{name}.png"))
    end

    def sign_in
      OmniAuth.config.mock_auth[:openid_connect] = OmniAuth::AuthHash.new(
        provider: "openid_connect", uid: "demo-sub", info: { name: "Dana Demo" },
        extra: { raw_info: { "iss" => "https://idp.example.com", "sub" => "demo-sub", "name" => "Dana Demo",
          "groups" => %w[team-platform trivista-users trivista-admins] } })
      visit login_path
      click_on "Sign in"
      assert_selector "h1", text: "Projects"
    end

    def seed_demo_project
      platform = Owner.create!(group_name: "team-platform")
      ci = ServiceAccount.create!(owner: platform, name: "ci-platform")
      project = Project.create!(owner: platform, name: "acme-platform", visibility: "group")
      billing = Project.create!(owner: Owner.create!(group_name: "team-billing"), name: "billing", visibility: "public")
      image = report("image.json")
      source = report("fs.json")
      image_findings, source_findings = image.findings, source.findings

      api = project.repos.create!(name: "platform-api")
      12.times do |index|
        findings = image_findings.first(image_findings.size - index).reject.with_index { |_, position| (position * 7 + index) % 23 == 0 }
        import(api, "main", image, findings, ci, index, at: (24 - index * 2).days.ago, trigger: %w[push push schedule push tag][index % 5],
          tag: ("v2.4.#{index / 5}" if index % 5 == 4))
      end
      import(api, "release/2.4", image, image_findings.first(40), ci, 20, at: 3.days.ago, trigger: "tag", tag: "v2.4.1")
      import(project.repos.create!(name: "platform-worker"), "develop", source, source_findings, ci, 21, at: 1.day.ago, trigger: "push")
      import(billing.repos.create!(name: "billing-service"), "main", source, source_findings.first(30), ci, 22, at: 5.hours.ago, trigger: "schedule")
      project
    end

    def import(repo, branch_name, report, findings, service_account, index, at:, trigger:, tag: nil)
      branch = repo.branches.find_by(name: branch_name) || repo.add_branch!(branch_name)
      report.instance_variable_set(:@findings, findings)
      ScanImporter.new(branch:, service_account:, commit_sha: Digest::SHA1.hexdigest("demo#{index}"), tag:, trigger:)
        .import(report).update!(created_at: at)
    end

    def report(name)
      TrivyReport.parse(file_fixture("trivy/#{name}").read)
    end
end
