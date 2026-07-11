class Product < ApplicationRecord
  belongs_to :campaign
  has_many :price_histories, dependent: :destroy

  validates :external_id, :name, presence: true
  validates :external_id, uniqueness: { scope: :campaign_id }
  validates :url, allow_blank: true, format: {
    with: URI::DEFAULT_PARSER.make_regexp([ "http", "https" ]),
    message: "must be a valid HTTP(S) URL"
  }

  def safe_url
    # Only return URL if it's properly formatted
    url.to_s.start_with?("http://", "https://") ? url : nil
  end
end
