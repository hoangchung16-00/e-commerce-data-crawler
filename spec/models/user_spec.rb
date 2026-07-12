require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it 'has many campaigns' do
      user = create(:user)
      campaign = create(:campaign, user: user)
      expect(user.campaigns).to include(campaign)
    end

    it 'destroys campaigns when user is deleted' do
      user = create(:user)
      campaign = create(:campaign, user: user)
      campaign_id = campaign.id
      user.destroy
      expect(Campaign.find_by(id: campaign_id)).to be_nil
    end
  end

  describe 'email' do
    it 'creates user with unique email' do
      user1 = create(:user, email: 'test@example.com')
      expect(user1.email).to eq('test@example.com')
    end

    it 'user has email attribute' do
      user = build(:user)
      expect(user).to respond_to(:email)
    end
  end

  describe 'campaigns relationship' do
    let(:user) { create(:user) }

    it 'creates campaigns associated with user' do
      campaign = create(:campaign, user: user)
      expect(user.campaigns).to include(campaign)
    end

    it 'returns all campaigns for user' do
      campaign1 = create(:campaign, user: user)
      campaign2 = create(:campaign, user: user)
      expect(user.campaigns.count).to eq(2)
    end
  end
end
