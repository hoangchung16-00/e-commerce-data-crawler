class PriceHistory < ApplicationRecord
  belongs_to :product

  validates :price, :recorded_at, presence: true
end
