class BranchesController < ApplicationController
  RANGES = { "7" => 7.days, "30" => 30.days, "90" => 90.days, "all" => nil }.freeze
  DEFAULT_RANGE = "90"

  def show
    @branch = Branch.visible_to(Current.user).find(params[:id])
    @finding_type = Finding::TYPES.include?(params[:type]) ? params[:type] : "vulnerability"
    @range = RANGES.key?(params[:range]) ? params[:range] : DEFAULT_RANGE
    @trigger = Scan::TRIGGERS.include?(params[:trigger]) ? params[:trigger] : nil
    @series = Trend.new(@branch, finding_type: @finding_type, since: RANGES[@range]&.ago, trigger: @trigger).series
  end
end
