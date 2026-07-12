require 'rails_helper'

RSpec.describe "Pages", type: :request do
  let(:user) { create(:user) }

  describe "GET /dashboard" do
    context "when not signed in" do
      it "redirects to login" do
        get "/dashboard"
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      before { sign_in user }

      it "returns http success" do
        get "/dashboard"
        expect(response).to have_http_status(:success)
      end

      it "contains dashboard heading" do
        get "/dashboard"
        expect(response.body).to include("Dashboard")
      end

      it "displays stats section" do
        get "/dashboard"
        expect(response.body).to include("Campaigns")
      end
    end
  end

  describe "GET /" do
    context "when not signed in" do
      it "redirects to login" do
        get "/"
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      before { sign_in user }

      it "returns http success" do
        get "/"
        expect(response).to have_http_status(:success)
      end

      it "displays the dashboard" do
        get "/"
        expect(response.body).to include("Dashboard")
      end
    end
  end
end
