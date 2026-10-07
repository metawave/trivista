class ScansController < ApplicationController
  def show
    @scan = Scan.visible_to(Current.user).find(params[:id])
  end
end
