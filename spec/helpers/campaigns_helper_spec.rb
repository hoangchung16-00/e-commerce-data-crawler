require 'rails_helper'

RSpec.describe CampaignsHelper, type: :helper do
  describe "helper methods" do
    it "has helper methods available" do
      expect(helper.respond_to?(:campaigns_path)).to be_truthy
    end
  end
end
