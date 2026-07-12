require 'rails_helper'

RSpec.describe "pages/dashboard.html.erb", type: :view do
  let(:user) { create(:user) }

  before do
    allow(view).to receive(:current_user).and_return(user)
  end

  describe 'dashboard layout' do
    before do
      assign(:campaigns, Campaign.where(user_id: user.id))
      assign(:recent_products, Product.none)
      render
    end

    it 'renders page title' do
      expect(view.content_for(:page_title)).to include('Dashboard')
    end

    it 'displays total campaigns stat' do
      expect(rendered).to include('Total Campaigns')
    end

    it 'displays active campaigns stat' do
      expect(rendered).to include('Active Campaigns')
    end

    it 'displays total products stat' do
      expect(rendered).to include('Total Products')
    end

    it 'displays price records stat' do
      expect(rendered).to include('Price Records')
    end
  end

  describe 'with campaigns' do
    before do
      create(:campaign, user: user, status: 'active')
      create(:campaign, user: user, status: 'paused')
      assign(:campaigns, user.campaigns)
      assign(:recent_products, Product.none)
      render
    end

    it 'displays recent campaigns section' do
      expect(rendered).to include('Recent Campaigns')
    end

    it 'shows view all campaigns link' do
      expect(rendered).to include(campaigns_path)
    end
  end

  describe 'with products' do
    before do
      campaign = create(:campaign, user: user)
      create(:product, campaign: campaign)
      create(:product, campaign: campaign)
      assign(:campaigns, user.campaigns)
      assign(:recent_products, Product.where(campaign_id: campaign.id))
      render
    end

    it 'displays recent products section' do
      expect(rendered).to include('Recent Products')
    end

    it 'shows view all products link' do
      expect(rendered).to include(products_path)
    end
  end
end
