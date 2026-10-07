# Deletes a project, repo, branch or scan with its findings data and keeps the owner quota in sync (ADR 0007).
class Purge
  def initialize(record)
    @record = record
  end

  def call
    Scan.transaction do
      owner = project.owner.lock!
      removed_occurrences = Occurrence.where(scan: scans).count
      repo = record.repo if record.is_a?(Branch)

      record.destroy!
      project.findings.where.missing(:occurrences).delete_all unless record.is_a?(Project)
      owner.update!(occurrence_count: owner.occurrence_count - removed_occurrences)
      reapply_default_branch(repo) if repo
    end
  end

  private
    attr_reader :record

    def project
      @project ||= case record
      when Project then record
      when Repo then record.project
      when Branch then record.repo.project
      when Scan then record.branch.repo.project
      end
    end

    def scans
      case record
      when Project then Scan.where(branch: Branch.where(repo: record.repos))
      when Repo then Scan.where(branch: record.branches)
      when Branch then record.scans
      when Scan then Scan.where(id: record.id)
      end
    end

    def reapply_default_branch(repo)
      repo.reload
      repo.update!(default_branch_manual: false) if repo.default_branch_id.nil?
      repo.apply_default_branch_rule!
    end
end
