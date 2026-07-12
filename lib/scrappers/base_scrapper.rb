require "nokogiri"
require_relative "errors"
require_relative "http_client"

class BaseScrapper
  attr_reader :url, :campaign, :logger

  REQUIRED_FIELDS = [ :name, :price ].freeze

  def initialize(url:, campaign:)
    @url = url
    @campaign = campaign
    @logger = Rails.logger
  end

  # Main execution method - Template Method pattern
  def call
    validate_url!
    response = fetch_page
    data = parse_response(response)
    validate_result(data)
    save_product(data)
  rescue Scrappers::ScraperError => e
    handle_error(e)
    raise
  rescue StandardError => e
    error = Scrappers::ParsingError.new("Unexpected error during scraping: #{e.message}")
    handle_error(error)
    raise error
  end

  # Override in subclasses
  def parse_response(response)
    raise NotImplementedError, "#{self.class} must implement #parse_response"
  end

  # Default implementation - override if needed
  def source_name
    raise NotImplementedError, "#{self.class} must implement #source_name"
  end

  protected

  # Template methods - can be overridden by subclasses

  def fetch_page
    logger.info("Fetching page: #{url}")
    response = Scrappers::HttpClient.get(url)

    unless response.success?
      raise Scrappers::NetworkError, "HTTP #{response.status} for URL: #{url}"
    end

    response.body
  end

  def validate_url!
    Scrappers::HttpClient.new.send(:validate_url!, url)
  rescue Scrappers::InvalidURLError => e
    logger.warn("Invalid URL: #{url} - #{e.message}")
    raise
  end

  def validate_result(data)
    raise Scrappers::MissingFieldError, "Result is nil" if data.nil?
    raise Scrappers::ValidationError, "Result must be a Hash" unless data.is_a?(Hash)

    REQUIRED_FIELDS.each do |field|
      raise Scrappers::MissingFieldError, "Missing required field: #{field}" if data[field].blank?
    end

    # Validate price is numeric
    unless data[:price].is_a?(Numeric)
      raise Scrappers::ValidationError, "Price must be numeric, got: #{data[:price].class}"
    end

    logger.info("Validation passed for URL: #{url}")
    data
  end

  def save_product(data)
    product_attrs = {
      external_id: generate_external_id(data),
      name: data[:name],
      url: url,
      image_url: data[:image_url],
      raw_attributes: (data[:raw_attributes] || {})
    }

    product = ActiveRecord::Base.transaction do
      product = campaign.products.find_or_initialize_by(
        external_id: product_attrs[:external_id]
      )
      product.update!(product_attrs)

      # Create price history entry
      PriceHistory.create!(
        product_id: product.id,
        price: data[:price],
        discount_rate: data[:discount_rate],
        recorded_at: Time.current
      )

      product
    end

    logger.info("Saved product: #{product.name} (ID: #{product.id})")
    product
  end

  def generate_external_id(data)
    # Override in subclasses for custom ID generation
    # Default: MD5 hash of URL
    Digest::MD5.hexdigest(url)
  end

  def handle_error(error)
    logger.error("Scraper error [#{self.class}]: #{error.message}")
    logger.debug("URL: #{url}, Campaign: #{campaign.id}")
    logger.debug(error.backtrace.join("\n")) if error.backtrace
  end

  # Helper methods for subclasses

  def parse_html(html_string)
    raise Scrappers::InvalidHTMLError, "HTML content is empty" if html_string.blank?

    doc = Nokogiri::HTML(html_string)
    raise Scrappers::InvalidHTMLError, "Failed to parse HTML" if doc.blank?

    doc
  rescue StandardError => e
    raise Scrappers::InvalidHTMLError, "HTML parsing failed: #{e.message}"
  end

  def extract_text(element, selector)
    return nil if element.nil? || selector.nil?

    node = element.at_css(selector)
    node&.text&.strip
  end

  def extract_number(text)
    return nil if text.blank?

    # Remove non-numeric characters except . and ,
    cleaned = text.gsub(/[^\d.,]/, "")

    # Replace comma with dot if it's likely a decimal separator
    cleaned = cleaned.tr(",", ".") if cleaned.count(".") <= 1

    cleaned.to_f.round(2)
  end

  def extract_price(text)
    price = extract_number(text)
    raise Scrappers::ValidationError, "Invalid price: #{text}" if price.nil? || price <= 0
    price
  end

  def extract_discount_rate(text)
    return nil if text.blank?

    rate = extract_number(text)
    rate = 0 if rate.nil?

    # Validate discount rate is between 0 and 100
    rate = 0 if rate < 0
    rate = 100 if rate > 100

    rate
  end
end
