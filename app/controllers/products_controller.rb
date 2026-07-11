class ProductsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_campaign, only: [ :index ]
  before_action :set_product, only: [ :show, :price_chart ]

  def index
    if @campaign
      @products = @campaign.products.page(params[:page]).per(20)
    else
      @products = Product.joins(:campaign).where(campaigns: { user_id: current_user.id }).page(params[:page]).per(20)
    end
  end

  def show
    @price_histories = @product.price_histories.order(recorded_at: :desc).limit(100)
    @chart_data = @product.price_histories
      .where(recorded_at: 30.days.ago..)
      .group_by_day(:recorded_at)
      .average(:price)
  end

  def price_chart
    @chart_data = @product.price_histories
      .where(recorded_at: params[:range].to_i.days.ago..)
      .group_by_day(:recorded_at)
      .average(:price)

    render json: @chart_data
  end

  private

  def set_campaign
    @campaign = Campaign.find(params[:campaign_id]) if params[:campaign_id].present?
  end

  def set_product
    @product = Product.find(params[:id])
  end
end
