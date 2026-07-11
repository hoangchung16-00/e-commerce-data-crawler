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
    return nil if url.blank?
    parsed = URI.parse(url)
    return nil unless parsed.is_a?(URI::HTTP)
    parsed.to_s
  rescue URI::InvalidURIError
    nil
  end
end
