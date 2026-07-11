class Campaign < ApplicationRecord
  belongs_to :user
  has_many :products, dependent: :destroy

  validates :name, :target_source, presence: true
  validates :status, inclusion: { in: %w[active paused stopped] }
  validates :frequency, inclusion: { in: %w[hourly daily manual] }
end
