class ProductsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_campaign, only: [ :index, :scrape ]
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

  def scrape
    url = params[:url]&.strip

    unless url.present?
      return render json: { success: false, error: "URL is required" }, status: :unprocessable_entity
    end

    unless url.match?(%r{^https?://})
      return render json: { success: false, error: "URL must start with http:// or https://" }, status: :unprocessable_entity
    end

    begin
      scraper = Scrappers::Factory.for(@campaign.target_source).new(url: url, campaign: @campaign)
      scraper.call

      # Get the newly created product
      product = Product.where(campaign_id: @campaign.id, external_id: scraper.generate_external_id({})).first

      if product
        render json: {
          success: true,
          message: "Product scraped successfully!",
          product: {
            id: product.id,
            name: product.name,
            external_id: product.external_id,
            price: product.price_histories.order(recorded_at: :desc).first&.price,
            discount_rate: product.price_histories.order(recorded_at: :desc).first&.discount_rate
          }
        }
      else
        render json: { success: false, error: "Product could not be found after scraping" }, status: :unprocessable_entity
      end
    rescue Scrappers::ScraperError => e
      render json: { success: false, error: "Scraper error: #{e.message}" }, status: :unprocessable_entity
    rescue StandardError => e
      render json: { success: false, error: "Error: #{e.message}" }, status: :internal_server_error
    end
  end

  private

  def set_campaign
    @campaign = Campaign.find(params[:campaign_id]) if params[:campaign_id].present?
  end

  def set_product
    @product = Product.find(params[:id])
  end
end
