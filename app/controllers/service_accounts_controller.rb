class ServiceAccountsController < ApplicationController
  def index
    @service_accounts = ServiceAccount.manageable_by(Current.user).includes(owner: :user).order(:name, :id)
  end

  def new
    @service_account = ServiceAccount.new
  end

  def create
    @service_account = ServiceAccount.new(name: params.dig(:service_account, :name), owner: selected_owner)
    if @service_account.owner.nil?
      @service_account.errors.add(:owner, "must be you or one of your groups")
      render :new, status: :unprocessable_content
    elsif @service_account.save
      redirect_to @service_account
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
    @service_account = ServiceAccount.manageable_by(Current.user).find(params[:id])
    @upload_token = UploadToken.new
  end

  private
    def selected_owner
      choice = params.dig(:service_account, :owner).to_s
      return Owner.find_or_create_by!(user: Current.user) if choice == "user"

      group = choice.delete_prefix("group:")
      Owner.find_or_create_by!(group_name: group) if choice.start_with?("group:") && Current.user.groups.include?(group)
    end
end
