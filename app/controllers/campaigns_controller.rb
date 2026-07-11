class CampaignsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_campaign, only: [ :show, :edit, :update, :destroy ]

  def index
    @campaigns = current_user.campaigns.page(params[:page]).per(10)
  end

  def show
    @products = @campaign.products.page(params[:page]).per(20)
  end

  def new
    @campaign = current_user.campaigns.build
  end

  def create
    @campaign = current_user.campaigns.build(campaign_params)
    if @campaign.save
      redirect_to @campaign, notice: "Campaign created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @campaign.update(campaign_params)
      redirect_to @campaign, notice: "Campaign updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @campaign.destroy
    redirect_to campaigns_url, notice: "Campaign deleted successfully."
  end

  private

  def set_campaign
    @campaign = current_user.campaigns.find(params[:id])
  end

  def campaign_params
    params.require(:campaign).permit(:name, :keyword, :target_source, :frequency, :status)
  end
end
