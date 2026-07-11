class Product < ApplicationRecord
  belongs_to :campaign
  has_many :price_histories, dependent: :destroy

  validates :external_id, :name, presence: true
  validates :external_id, uniqueness: { scope: :campaign_id }
end
