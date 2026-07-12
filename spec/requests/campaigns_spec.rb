require 'rails_helper'

RSpec.describe "Campaigns", type: :request do
  let(:user) { create(:user) }
  let(:campaign) { create(:campaign, user: user) }

  before { sign_in user }

  describe "GET /campaigns (index)" do
    context "when not signed in" do
      before { sign_out user }

      it "redirects to login" do
        get "/campaigns"
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      it "returns http success" do
        get "/campaigns"
        expect(response).to have_http_status(:success)
      end

      it "displays campaigns page" do
        get "/campaigns"
        expect(response.body).to include("Campaign")
      end

      context "with campaigns" do
        before do
          create(:campaign, user: user)
          create(:campaign, user: user)
        end

        it "displays campaign list" do
          get "/campaigns"
          expect(Campaign.where(user_id: user.id).count).to eq(2)
        end
      end
    end
  end

  describe "GET /campaigns/:id (show)" do
    context "when not signed in" do
      before { sign_out user }

      it "redirects to login" do
        get "/campaigns/#{campaign.id}"
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      it "returns http success" do
        get "/campaigns/#{campaign.id}"
        expect(response).to have_http_status(:success)
      end

      it "displays campaign details" do
        get "/campaigns/#{campaign.id}"
        expect(response.body).to include(campaign.name)
      end
    end
  end

  describe "GET /campaigns/new (new)" do
    it "returns http success" do
      get "/campaigns/new"
      expect(response).to have_http_status(:success)
    end

    it "displays new campaign form" do
      get "/campaigns/new"
      expect(response.body).to include("New Campaign")
    end
  end

  describe "POST /campaigns (create)" do
    let(:campaign_params) do
      {
        campaign: {
          name: 'Test Campaign',
          keyword: 'test keyword',
          target_source: 'tiki',
          frequency: 'daily',
          status: 'active'
        }
      }
    end

    it "creates a new campaign" do
      expect {
        post "/campaigns", params: campaign_params
      }.to change(Campaign, :count).by(1)
    end

    it "redirects to campaign show page" do
      post "/campaigns", params: campaign_params
      expect(response).to redirect_to(campaign_path(Campaign.last))
    end

    it "associates campaign with current user" do
      post "/campaigns", params: campaign_params
      expect(Campaign.last.user).to eq(user)
    end
  end

  describe "GET /campaigns/:id/edit (edit)" do
    it "returns http success" do
      get "/campaigns/#{campaign.id}/edit"
      expect(response).to have_http_status(:success)
    end

    it "displays edit form" do
      get "/campaigns/#{campaign.id}/edit"
      expect(response.body).to include("Edit Campaign")
    end
  end

  describe "PATCH /campaigns/:id (update)" do
    let(:update_params) do
      {
        campaign: {
          name: 'Updated Campaign Name'
        }
      }
    end

    it "updates the campaign" do
      patch "/campaigns/#{campaign.id}", params: update_params
      campaign.reload
      expect(campaign.name).to eq('Updated Campaign Name')
    end

    it "redirects to campaign show page" do
      patch "/campaigns/#{campaign.id}", params: update_params
      expect(response).to redirect_to(campaign_path(campaign))
    end
  end

  describe "DELETE /campaigns/:id (destroy)" do
    let!(:campaign_id) { campaign.id }

    it "deletes the campaign" do
      expect {
        delete "/campaigns/#{campaign_id}"
      }.to change(Campaign, :count).by(-1)
    end

    it "redirects to campaigns index" do
      delete "/campaigns/#{campaign_id}"
      expect(response).to redirect_to(campaigns_path)
    end
  end
end
