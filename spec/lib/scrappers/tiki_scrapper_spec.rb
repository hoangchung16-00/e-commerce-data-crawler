require 'rails_helper'

RSpec.describe Scrappers::TikiScrapper, type: :lib do
  let(:user) { create(:user) }
  let(:campaign) { create(:campaign, user: user, target_source: 'tiki') }
  let(:url) { 'https://tiki.vn/p/123456' }
  let(:scraper) { Scrappers::TikiScrapper.new(url: url, campaign: campaign) }

  describe '#source_name' do
    it 'returns tiki' do
      expect(scraper.source_name).to eq('tiki')
    end
  end

  describe '#generate_external_id' do
    context 'with standard Tiki URL format' do
      it 'extracts product ID from /p/ format' do
        scraper = Scrappers::TikiScrapper.new(url: 'https://tiki.vn/p/987654', campaign: campaign)
        id = scraper.send(:generate_external_id, {})
        expect(id).to eq('987654')
      end

      it 'extracts product ID from /product/ format' do
        scraper = Scrappers::TikiScrapper.new(url: 'https://tiki.vn/product/111222', campaign: campaign)
        id = scraper.send(:generate_external_id, {})
        expect(id).to eq('111222')
      end
    end

    context 'with non-standard URL format' do
      it 'falls back to MD5 hash' do
        scraper = Scrappers::TikiScrapper.new(url: 'https://tiki.vn/search/product', campaign: campaign)
        id = scraper.send(:generate_external_id, {})
        expect(id).to eq(Digest::MD5.hexdigest('https://tiki.vn/search/product'))
      end
    end
  end

  describe '#parse_response' do
    let(:html_response) do
      <<~HTML
        <html>
          <h1 class="product-name">iPhone 14 Pro Max 128GB</h1>
          <span class="product-price-current">29.990.000</span>
          <span class="discount-rate">10%</span>
          <img class="product-image" src="https://salt.tikicdn.com/cache/100x100/ts/product/image.jpg" />
          <span class="product-sku">SKU-12345</span>
          <a class="breadcrumb-item">Điện thoại</a>
          <span class="availability">In stock</span>
          <table class="specification">
            <tr>
              <td>Brand</td>
              <td>Apple</td>
            </tr>
            <tr>
              <td>Model</td>
              <td>iPhone 14 Pro Max</td>
            </tr>
          </table>
        </html>
      HTML
    end

    it 'extracts product name' do
      data = scraper.parse_response(html_response)
      expect(data[:name]).to eq('iPhone 14 Pro Max 128GB')
    end

    it 'extracts and converts price' do
      data = scraper.parse_response(html_response)
      expect(data[:price]).to eq(29_990_000.0)
    end

    it 'extracts discount rate' do
      data = scraper.parse_response(html_response)
      expect(data[:discount_rate]).to eq(10.0)
    end

    it 'extracts image URL' do
      data = scraper.parse_response(html_response)
      expect(data[:image_url]).to include('tikicdn.com')
    end

    it 'extracts raw attributes' do
      data = scraper.parse_response(html_response)
      expect(data[:raw_attributes][:sku]).to eq('SKU-12345')
      expect(data[:raw_attributes][:category]).to eq('Điện thoại')
      expect(data[:raw_attributes][:availability]).to eq('In stock')
      expect(data[:raw_attributes][:brand]).to eq('Apple')
      expect(data[:raw_attributes][:model]).to eq('iPhone 14 Pro Max')
    end

    context 'with missing name' do
      let(:html_response) do
        <<~HTML
          <html>
            <span class="product-price-current">29.990.000</span>
          </html>
        HTML
      end

      it 'raises MissingFieldError' do
        expect { scraper.parse_response(html_response) }.to raise_error(
          Scrappers::MissingFieldError
        )
      end
    end

    context 'with missing price' do
      let(:html_response) do
        <<~HTML
          <html>
            <h1 class="product-name">iPhone 14 Pro Max 128GB</h1>
          </html>
        HTML
      end

      it 'raises MissingFieldError' do
        expect { scraper.parse_response(html_response) }.to raise_error(
          Scrappers::MissingFieldError
        )
      end
    end

    context 'with data-view-tracking attributes' do
      let(:html_response) do
        <<~HTML
          <html>
            <h1 data-view-tracking="product_name">Product Name</h1>
            <span data-price="regular">1000</span>
            <span data-view-tracking="discount_rate">5%</span>
            <img data-view-tracking="product_image" src="https://example.com/image.jpg" />
          </html>
        HTML
      end

      it 'finds elements by data-view-tracking selectors' do
        data = scraper.parse_response(html_response)
        expect(data[:name]).to eq('Product Name')
        expect(data[:price]).to eq(1000.0)
        expect(data[:discount_rate]).to eq(5.0)
      end
    end
  end

  describe '#extract_name' do
    context 'with valid name' do
      let(:html) do
        '<html><h1 class="product-name">Test Product</h1></html>'
      end

      it 'extracts product name' do
        doc = Nokogiri::HTML(html)
        name = scraper.send(:extract_name, doc)
        expect(name).to eq('Test Product')
      end
    end

    context 'without name' do
      let(:html) do
        '<html><body></body></html>'
      end

      it 'raises MissingFieldError' do
        doc = Nokogiri::HTML(html)
        expect { scraper.send(:extract_name, doc) }.to raise_error(
          Scrappers::MissingFieldError
        )
      end
    end
  end

  describe '#extract_price_value' do
    context 'with valid price in standard format' do
      let(:html) do
        '<html><span class="product-price-current">99.990</span></html>'
      end

      it 'extracts and converts price' do
        doc = Nokogiri::HTML(html)
        price = scraper.send(:extract_price_value, doc)
        expect(price).to eq(99_990.0)
      end
    end

    context 'with price using comma separator' do
      let(:html) do
        '<html><span class="product-price-current">99,990</span></html>'
      end

      it 'converts comma to dot and extracts price' do
        doc = Nokogiri::HTML(html)
        price = scraper.send(:extract_price_value, doc)
        expect(price).to eq(99_990.0)
      end
    end

    context 'without price' do
      let(:html) do
        '<html><body></body></html>'
      end

      it 'raises MissingFieldError' do
        doc = Nokogiri::HTML(html)
        expect { scraper.send(:extract_price_value, doc) }.to raise_error(
          Scrappers::MissingFieldError
        )
      end
    end
  end

  describe '#extract_discount_value' do
    context 'with valid discount rate' do
      let(:html) do
        '<html><span class="discount-rate">15%</span></html>'
      end

      it 'extracts discount rate' do
        doc = Nokogiri::HTML(html)
        discount = scraper.send(:extract_discount_value, doc)
        expect(discount).to eq(15.0)
      end
    end

    context 'without discount' do
      let(:html) do
        '<html><body></body></html>'
      end

      it 'returns 0' do
        doc = Nokogiri::HTML(html)
        discount = scraper.send(:extract_discount_value, doc)
        expect(discount).to eq(0)
      end
    end
  end

  describe '#extract_image_url' do
    context 'with absolute URL in src' do
      let(:html) do
        '<html><img class="product-image" src="https://example.com/image.jpg" /></html>'
      end

      it 'returns absolute URL' do
        doc = Nokogiri::HTML(html)
        url = scraper.send(:extract_image_url, doc)
        expect(url).to eq('https://example.com/image.jpg')
      end
    end

    context 'with protocol-relative URL' do
      let(:html) do
        '<html><img class="product-image" src="//cdn.example.com/image.jpg" /></html>'
      end

      it 'converts to https URL' do
        doc = Nokogiri::HTML(html)
        url = scraper.send(:extract_image_url, doc)
        expect(url).to eq('https://cdn.example.com/image.jpg')
      end
    end

    context 'with data-src attribute' do
      let(:html) do
        '<html><img class="product-image" data-src="https://example.com/image.jpg" /></html>'
      end

      it 'extracts URL from data-src' do
        doc = Nokogiri::HTML(html)
        url = scraper.send(:extract_image_url, doc)
        expect(url).to eq('https://example.com/image.jpg')
      end
    end

    context 'without image' do
      let(:html) do
        '<html><body></body></html>'
      end

      it 'returns nil' do
        doc = Nokogiri::HTML(html)
        url = scraper.send(:extract_image_url, doc)
        expect(url).to be_nil
      end
    end
  end

  describe '#extract_raw_attributes' do
    let(:html) do
      <<~HTML
        <html>
          <span class="product-sku">SKU-ABC-123</span>
          <a class="breadcrumb-item">Electronics</a>
          <span class="availability">In stock</span>
          <table class="specification">
            <tr>
              <td>Color</td>
              <td>Black</td>
            </tr>
            <tr>
              <td>Storage</td>
              <td>256GB</td>
            </tr>
          </table>
        </html>
      HTML
    end

    it 'extracts all available attributes' do
      doc = Nokogiri::HTML(html)
      attrs = scraper.send(:extract_raw_attributes, doc)
      expect(attrs[:sku]).to eq('SKU-ABC-123')
      expect(attrs[:category]).to eq('Electronics')
      expect(attrs[:availability]).to eq('In stock')
      expect(attrs[:color]).to eq('Black')
      expect(attrs[:storage]).to eq('256GB')
    end
  end

  describe '#extract_specifications' do
    context 'with table format' do
      let(:html) do
        <<~HTML
          <table class="specification">
            <tr>
              <td>Brand</td>
              <td>Samsung</td>
            </tr>
            <tr>
              <td>Screen Size</td>
              <td>6.1 inches</td>
            </tr>
          </table>
        HTML
      end

      it 'extracts specifications from table' do
        doc = Nokogiri::HTML(html)
        specs = scraper.send(:extract_specifications, doc)
        expect(specs[:brand]).to eq('Samsung')
        expect(specs[:screen_size]).to eq('6.1 inches')
      end
    end

    context 'with definition list format' do
      let(:html) do
        <<~HTML
          <dl class="spec-list">
            <dt>CPU</dt>
            <dd>Snapdragon 8 Gen 1</dd>
            <dt>RAM</dt>
            <dd>8GB</dd>
          </dl>
        HTML
      end

      it 'extracts specifications from definition list' do
        doc = Nokogiri::HTML(html)
        specs = scraper.send(:extract_specifications, doc)
        expect(specs[:cpu]).to eq('Snapdragon 8 Gen 1')
        expect(specs[:ram]).to eq('8GB')
      end
    end

    context 'with no specifications' do
      let(:html) do
        '<html><body></body></html>'
      end

      it 'returns empty hash' do
        doc = Nokogiri::HTML(html)
        specs = scraper.send(:extract_specifications, doc)
        expect(specs).to eq({})
      end
    end
  end

  describe '#call (full integration)' do
    let(:html_response) do
      <<~HTML
        <html>
          <h1 class="product-name">Samsung Galaxy S23</h1>
          <span class="product-price-current">15.990.000</span>
          <span class="discount-rate">8%</span>
          <img class="product-image" src="https://salt.tikicdn.com/cache/product.jpg" />
          <span class="product-sku">SKU-S23</span>
          <a class="breadcrumb-item">Smartphones</a>
          <table class="specification">
            <tr>
              <td>Storage</td>
              <td>256GB</td>
            </tr>
          </table>
        </html>
      HTML
    end

    before do
      allow(Scrappers::HttpClient).to receive(:get).and_return(
        double(success?: true, body: html_response)
      )
    end

    it 'orchestrates full scraping workflow' do
      result = scraper.call
      expect(result).to be_a(Product)
      expect(result.name).to eq('Samsung Galaxy S23')
      expect(result.campaign).to eq(campaign)
    end

    it 'creates price history entry' do
      expect { scraper.call }.to change(PriceHistory, :count).by(1)
      price_history = PriceHistory.last
      expect(price_history.price).to eq(15_990_000.0)
      expect(price_history.discount_rate).to eq(8.0)
    end

    it 'extracts external ID from URL' do
      scraper_with_id_url = Scrappers::TikiScrapper.new(
        url: 'https://tiki.vn/p/555666',
        campaign: campaign
      )
      allow(Scrappers::HttpClient).to receive(:get).and_return(
        double(success?: true, body: html_response)
      )

      product = scraper_with_id_url.call
      expect(product.external_id).to eq('555666')
    end
  end
end
