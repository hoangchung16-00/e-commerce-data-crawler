class PagesController < ApplicationController
  before_action :authenticate_user!

  def dashboard
    @campaigns = current_user.campaigns.includes(:products)
    @recent_products = current_user.campaigns.flat_map(&:products).sort_by(&:updated_at).reverse.take(10)
  end
end
