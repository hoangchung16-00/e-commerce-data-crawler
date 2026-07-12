require_relative "base_scrapper"

module Scrappers
  class TikiScrapper < BaseScrapper
    # Tiki-specific selectors for product information
    SELECTORS = {
      name: 'h1.product-name, h1[data-view-tracking="product_name"], h1',
      price: 'div.product-price__current-price, div.product-price, span.product-price-current, span[data-price="regular"]',
      discount_rate: 'span.discount-rate, span[data-view-tracking="discount_rate"]',
      image_url: 'picture img, img.product-image, img[data-view-tracking="product_image"]',
      sku: 'span.product-sku, [data-view-tracking="product_sku"]',
      category: '.breadcrumb-item, a.breadcrumb-item, [data-view-tracking="category"]',
      availability: 'span.availability, [data-view-tracking="availability"]'
    }.freeze

    def parse_response(response)
      doc = parse_html(response)

      {
        name: extract_name(doc),
        price: extract_price_value(doc),
        discount_rate: extract_discount_value(doc),
        image_url: extract_image_url(doc),
        raw_attributes: extract_raw_attributes(doc)
      }
    end

    def source_name
      "tiki"
    end

    def generate_external_id(data)
      # Try to extract product ID from URL (format: /p/{product_id} or /product/{product_id})
      match = url.match(%r{/p/(\d+)})
      return match[1] if match

      match = url.match(%r{/product/(\d+)})
      return match[1] if match

      # Fallback to URL hash if product ID not found
      Digest::MD5.hexdigest(url)
    end

    private

    def extract_name(doc)
      text = extract_text(doc, SELECTORS[:name])
      raise Scrappers::MissingFieldError, "Product name not found" if text.blank?
      text
    end

    def extract_price_value(doc)
      # Tiki price format: "123.456" or "123,456" VND (Vietnamese format: dot=thousands, comma=decimal)
      price_text = extract_text(doc, SELECTORS[:price])
      raise Scrappers::MissingFieldError, "Product price not found" if price_text.blank?

      # Convert Vietnamese number format to standard format
      # Remove all non-numeric characters except comma and dot
      cleaned = price_text.gsub(/[^\d.,]/, "").strip

      # Vietnamese format: dots are thousands separators, comma is decimal separator
      # Example: 29.990.000 = 29990000, or 1.500,99 = 1500.99
      # If only comma (no dots): 99,990 could be 99.99 or 99990 depending on context
      # Heuristic: if there's only a comma and 3 digits after comma, it's likely a thousands separator
      dot_count = cleaned.count(".")
      comma_count = cleaned.count(",")

      if dot_count.zero? && comma_count == 1
        # Only comma, no dots
        # Check digits after comma: if 3, it's thousands separator; if 1-2, it's decimal
        parts = cleaned.split(",")
        if parts[1].length == 3
          # Likely thousands: 99,990 = 99990
          cleaned = cleaned.tr(",", "")
        else
          # Likely decimal: 99,99 = 99.99
          cleaned = cleaned.tr(",", ".")
        end
      elsif comma_count > 0
        # Has both dots and comma: dots are thousands, comma is decimal
        cleaned = cleaned.gsub(".", "").tr(",", ".")
      else
        # Only dots: they're thousands separators
        cleaned = cleaned.gsub(".", "")
      end

      price = cleaned.to_f
      raise Scrappers::ValidationError, "Invalid price: #{price_text}" if price.nil? || price <= 0
      price.round(2)
    end

    def extract_discount_value(doc)
      # Tiki discount format: "50%" or "50 %"
      discount_text = extract_text(doc, SELECTORS[:discount_rate])
      extract_discount_rate(discount_text) || 0
    end

    def extract_image_url(doc)
      # Try to get image URL from img tag or data attribute
      img_element = doc.at_css(SELECTORS[:image_url])
      return nil unless img_element

      # Try src, data-src, or other attributes
      url = img_element.attr("src") || img_element.attr("data-src") || img_element.attr("data-thumb-url")
      return nil if url.blank?

      # Ensure URL is absolute
      url = "https:#{url}" if url.start_with?("//")
      url
    end

    def extract_raw_attributes(doc)
      attributes = {}

      # Extract SKU
      sku = extract_text(doc, SELECTORS[:sku])
      attributes[:sku] = sku if sku.present?

      # Extract category (get last breadcrumb item)
      category_elements = doc.css(SELECTORS[:category])
      if category_elements.any?
        category = category_elements.last.text.strip
        attributes[:category] = category if category.present?
      end

      # Extract availability
      availability = extract_text(doc, SELECTORS[:availability])
      attributes[:availability] = availability if availability.present?

      # Extract additional specs from spec table if available
      extract_specifications(doc).each do |key, value|
        attributes[key] = value
      end

      attributes
    end

    def extract_specifications(doc)
      specs = {}

      # Look for specification table or list
      spec_elements = doc.css("table.specification tr, div.specification-item, dl.spec-list dt")

      spec_elements.each do |element|
        if element.name == "tr"
          # Table format: <tr><td>Key</td><td>Value</td></tr>
          cells = element.css("td")
          if cells.length >= 2
            key = cells[0].text.strip.downcase.gsub(/\s+/, "_").to_sym
            value = cells[1].text.strip
            specs[key] = value if key.present? && value.present?
          end
        elsif element.name == "dt"
          # Definition list format
          key = element.text.strip.downcase.gsub(/\s+/, "_").to_sym
          dd = element.next_element
          if dd && dd.name == "dd"
            value = dd.text.strip
            specs[key] = value if key.present? && value.present?
          end
        elsif element.name == "div"
          # Div spec format with span children
          spec_name = element.at_css(".spec-name")&.text&.strip
          spec_value = element.at_css(".spec-value")&.text&.strip
          if spec_name.present? && spec_value.present?
            key = spec_name.downcase.gsub(/\s+/, "_").to_sym
            specs[key] = spec_value
          end
        end
      end

      specs
    end
  end
end
