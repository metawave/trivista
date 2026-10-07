# Imports a report into the namespace of the service account owner, under the owner's quota (ADR 0004, ADR 0005).
class Upload
  class QuotaExceeded < StandardError; end

  def initialize(service_account:, project:, repo:, branch:, commit:, report:, tag: nil, trigger: "unknown",
    occurrence_quota: Rails.configuration.x.occurrence_quota)
    @service_account = service_account
    @project_name = project
    @repo_name = repo
    @branch_name = branch
    @commit = commit
    @report = report
    @tag = tag
    @trigger = trigger
    @occurrence_quota = occurrence_quota
  end

  def import
    Scan.transaction do
      owner = service_account.owner.lock!
      scan = ScanImporter.new(branch: branch_of(owner), service_account:, commit_sha: commit, tag:, trigger:).import(report)
      occurrence_count = owner.occurrence_count + scan.occurrences.count
      raise QuotaExceeded if occurrence_count > occurrence_quota

      owner.update!(occurrence_count:)
      scan
    end
  end

  private
    attr_reader :service_account, :project_name, :repo_name, :branch_name, :commit, :report, :tag, :trigger, :occurrence_quota

    def branch_of(owner)
      project = owner.projects.find_or_create_by!(name: project_name) { it.visibility = owner.user? ? "user" : "group" }
      repo = project.repos.find_or_create_by!(name: repo_name)
      repo.branches.find_by(name: branch_name) || repo.add_branch!(branch_name)
    end
end
