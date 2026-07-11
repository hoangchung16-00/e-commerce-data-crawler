module ProductsHelper
  def safe_product_url(url)
    # Return nil if URL is blank
    return nil if url.blank?

    uri = begin
      URI.parse(url)
    rescue URI::InvalidURIError
      return nil
    end

    # Only allow http and https schemes
    return nil unless [ "http", "https" ].include?(uri.scheme)

    # Return the validated URL as a string
    url.to_s
  end
end
