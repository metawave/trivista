class DesignController < ApplicationController
  SampleDiff = Data.define(:predecessor, :new_finding_ids, :no_longer_reported_finding_ids)

  skip_before_action :require_login

  def show
    @diff = SampleDiff.new(predecessor: true, new_finding_ids: [ 1, 2 ], no_longer_reported_finding_ids: [ 3 ])
    @first_diff = SampleDiff.new(predecessor: nil, new_finding_ids: [], no_longer_reported_finding_ids: [])
  end
end
