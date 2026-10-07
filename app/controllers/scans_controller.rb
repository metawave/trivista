class ScansController < ApplicationController
  # ponytail: rows are capped instead of paginated; add pagination if scans regularly exceed the cap.
  ROW_LIMIT = 500

  def show
    @scan = Scan.visible_to(Current.user).includes(:artifact, service_account: { owner: :user }, branch: { repo: :project }).find(params[:id])
    @finding_type = Finding::TYPES.include?(params[:type]) ? params[:type] : nil
    @severity = Occurrence::SEVERITIES.include?(params[:severity]) ? params[:severity] : nil
    @only_new = params[:only_new] == "1"
    @diff = ScanDiff.new(@scan)

    rows = ScanFindings.new(@scan, finding_ids: (@diff.new_finding_ids if @only_new))
      .rows(finding_type: @finding_type, severity: @severity)
    @row_count = rows.size
    @rows = rows.first(ROW_LIMIT)
    @new_finding_ids = @diff.new_finding_ids.to_set
    @no_longer_reported = @diff.predecessor ?
      ScanFindings.new(@diff.predecessor, finding_ids: @diff.no_longer_reported_finding_ids)
        .rows(finding_type: @finding_type, severity: @severity).first(ROW_LIMIT) : []
  end

  def destroy
    scan = Scan.where(branch: Branch.where(repo: Repo.where(project: manageable_projects))).find(params[:id])
    Purge.new(scan).call
    redirect_to scan.branch, notice: "Scan deleted."
  end
end
