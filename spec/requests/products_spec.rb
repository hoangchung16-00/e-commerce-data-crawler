require 'rails_helper'

RSpec.describe "Products", type: :request do
  let(:user) { create(:user) }
  let(:campaign) { create(:campaign, user: user) }
  let(:product) { create(:product, campaign: campaign) }

  before { sign_in user }

  describe "GET /products (index)" do
    context "when not signed in" do
      before { sign_out user }

      it "redirects to login" do
        get "/products"
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      it "returns http success" do
        get "/products"
        expect(response).to have_http_status(:success)
      end

      it "displays products page" do
        get "/products"
        expect(response.body).to include("Products")
      end

      context "with products" do
        before do
          create(:product, campaign: campaign)
          create(:product, campaign: campaign)
        end

        it "displays product list" do
          get "/products"
          expect(response.body).to include(campaign.name)
        end
      end
    end
  end

  describe "GET /products/:id (show)" do
    context "when not signed in" do
      before { sign_out user }

      it "redirects to login" do
        get "/products/#{product.id}"
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      it "returns http success" do
        get "/products/#{product.id}"
        expect(response).to have_http_status(:success)
      end

      it "displays product details" do
        get "/products/#{product.id}"
        expect(response.body).to include(product.name)
      end

      it "displays campaign link" do
        get "/products/#{product.id}"
        expect(response.body).to include(campaign.name)
      end
    end
  end

  describe "GET /products/:id/price_chart (price_chart)" do
    context "when not signed in" do
      before { sign_out user }

      it "redirects to login" do
        get "/products/#{product.id}/price_chart"
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      before do
        create(:price_history, product: product, price: 99.99)
        create(:price_history, product: product, price: 89.99)
      end

      it "returns json data" do
        get "/products/#{product.id}/price_chart"
        expect(response.content_type).to include("application/json")
      end

      it "returns price history data grouped by day" do
        get "/products/#{product.id}/price_chart"
        data = JSON.parse(response.body)
        expect(data).to be_a(Hash)
      end
    end
  end

  describe "GET /campaigns/:campaign_id/products (nested index)" do
    context "when not signed in" do
      before { sign_out user }

      it "redirects to login" do
        get "/campaigns/#{campaign.id}/products"
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      before do
        create(:product, campaign: campaign)
      end

      it "returns http success" do
        get "/campaigns/#{campaign.id}/products"
        expect(response).to have_http_status(:success)
      end

      it "displays products for campaign" do
        get "/campaigns/#{campaign.id}/products"
        expect(response.body).to include(campaign.name)
      end
    end
  end

  describe "GET /campaigns/:campaign_id/products/:id (nested show)" do
    context "when signed in" do
      it "returns http success" do
        get "/campaigns/#{campaign.id}/products/#{product.id}"
        expect(response).to have_http_status(:success)
      end

      it "displays product details" do
        get "/campaigns/#{campaign.id}/products/#{product.id}"
        expect(response.body).to include(product.name)
      end
    end
  end
end
