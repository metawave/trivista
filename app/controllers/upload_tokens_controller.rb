class UploadTokensController < ApplicationController
  def create
    @service_account = ServiceAccount.manageable_by(Current.user).find(params[:service_account_id])
    @upload_token, @secret = UploadToken.issue!(service_account: @service_account, created_by: Current.user, expires_at:)
    response.headers["Cache-Control"] = "no-store"
    render :created
  rescue ActiveRecord::RecordInvalid => error
    @upload_token = error.record
    render "service_accounts/show", status: :unprocessable_content
  end

  def destroy
    upload_token = UploadToken.where(service_account: ServiceAccount.manageable_by(Current.user)).find(params[:id])
    upload_token.revoke!
    redirect_to upload_token.service_account
  end

  private
    def expires_at
      Date.iso8601(params.dig(:upload_token, :expires_on).to_s).end_of_day
    rescue Date::Error
      nil
    end
end
