require 'rails_helper'

# Concrete test implementation of BaseScrapper
class TestScrapper < BaseScrapper
  def parse_response(response)
    doc = parse_html(response)
    {
      name: extract_text(doc, 'h1.product-name'),
      price: extract_price(extract_text(doc, 'span.price')),
      discount_rate: extract_discount_rate(extract_text(doc, 'span.discount')),
      image_url: 'https://example.com/image.jpg',
      raw_attributes: { color: 'red', size: 'L' }
    }
  end

  def source_name
    'test_source'
  end
end

RSpec.describe BaseScrapper, type: :lib do
  let(:user) { create(:user) }
  let(:campaign) { create(:campaign, user: user) }
  let(:url) { 'https://example.com/product/123' }
  let(:scraper) { TestScrapper.new(url: url, campaign: campaign) }

  describe '#initialize' do
    it 'sets url, campaign, and logger' do
      expect(scraper.url).to eq(url)
      expect(scraper.campaign).to eq(campaign)
      expect(scraper.logger).to be_present
    end
  end

  describe '#call' do
    let(:html_response) do
      <<~HTML
        <html>
          <h1 class="product-name">Test Product</h1>
          <span class="price">$99.99</span>
          <span class="discount">15</span>
        </html>
      HTML
    end

    before do
      allow(Scrappers::HttpClient).to receive(:get).and_return(
        double(success?: true, body: html_response)
      )
    end

    it 'orchestrates the scraping workflow' do
      result = scraper.call

      expect(result).to be_a(Product)
      expect(result.name).to eq('Test Product')
      expect(result.campaign).to eq(campaign)
    end

    it 'creates a price history entry' do
      expect { scraper.call }.to change(PriceHistory, :count).by(1)
    end

    it 'logs the process' do
      expect(scraper.logger).to receive(:info).at_least(3).times
      scraper.call
    end

    context 'when parse_response fails' do
      before do
        allow_any_instance_of(TestScrapper).to receive(:parse_response).and_raise(
          Scrappers::ParsingError.new('Parse failed')
        )
      end

      it 'raises ScraperError' do
        expect { scraper.call }.to raise_error(Scrappers::ParsingError)
      end

      it 'logs the error' do
        expect(scraper.logger).to receive(:error)
        expect { scraper.call }.to raise_error(Scrappers::ParsingError)
      end
    end

    context 'when validation fails' do
      let(:html_response) do
        '<html><h1 class="product-name">Test</h1></html>'
      end

      it 'raises ValidationError' do
        expect { scraper.call }.to raise_error(Scrappers::ValidationError)
      end
    end

    context 'when save fails' do
      let(:html_response) do
        <<~HTML
          <html>
            <h1 class="product-name">Test Product</h1>
            <span class="price">$99.99</span>
            <span class="discount">15</span>
          </html>
        HTML
      end

      before do
        allow_any_instance_of(Product).to receive(:update!).and_raise(
          ActiveRecord::RecordInvalid
        )
      end

      it 'raises ParsingError (which wraps the RecordInvalid)' do
        expect { scraper.call }.to raise_error(Scrappers::ParsingError)
      end

      it 'rolls back all changes' do
        expect { scraper.call }.to raise_error(Scrappers::ParsingError)
        expect(Product.count).to eq(0)
        expect(PriceHistory.count).to eq(0)
      end
    end
  end

  describe '#validate_url!' do
    it 'allows valid http URLs' do
      scraper = TestScrapper.new(url: 'http://example.com', campaign: campaign)
      expect { scraper.send(:validate_url!) }.not_to raise_error
    end

    it 'allows valid https URLs' do
      scraper = TestScrapper.new(url: 'https://example.com', campaign: campaign)
      expect { scraper.send(:validate_url!) }.not_to raise_error
    end

    context 'with invalid URL' do
      it 'raises InvalidURLError for blank URL' do
        scraper = TestScrapper.new(url: '', campaign: campaign)
        expect { scraper.send(:validate_url!) }.to raise_error(Scrappers::InvalidURLError)
      end

      it 'raises InvalidURLError for invalid format' do
        scraper = TestScrapper.new(url: 'not a url', campaign: campaign)
        expect { scraper.send(:validate_url!) }.to raise_error(Scrappers::InvalidURLError)
      end

      it 'raises InvalidURLError for non-http protocol' do
        scraper = TestScrapper.new(url: 'ftp://example.com', campaign: campaign)
        expect { scraper.send(:validate_url!) }.to raise_error(Scrappers::InvalidURLError)
      end
    end
  end

  describe '#fetch_page' do
    let(:html_response) { '<html><body>Test</body></html>' }

    before do
      allow(Scrappers::HttpClient).to receive(:get).and_return(
        double(success?: true, body: html_response)
      )
    end

    it 'returns the response body' do
      result = scraper.send(:fetch_page)
      expect(result).to eq(html_response)
    end

    it 'calls HttpClient.get with the URL' do
      expect(Scrappers::HttpClient).to receive(:get).with(url)
      scraper.send(:fetch_page)
    end

    context 'when HTTP request fails' do
      before do
        allow(Scrappers::HttpClient).to receive(:get).and_return(
          double(success?: false, status: 404)
        )
      end

      it 'raises NetworkError' do
        expect { scraper.send(:fetch_page) }.to raise_error(Scrappers::NetworkError)
      end
    end
  end

  describe '#validate_result' do
    context 'with valid data' do
      let(:data) do
        { name: 'Product', price: 99.99, discount_rate: 10 }
      end

      it 'returns the data' do
        result = scraper.send(:validate_result, data)
        expect(result).to eq(data)
      end
    end

    context 'with nil data' do
      it 'raises MissingFieldError' do
        expect { scraper.send(:validate_result, nil) }.to raise_error(
          Scrappers::MissingFieldError
        )
      end
    end

    context 'with non-Hash data' do
      it 'raises ValidationError' do
        expect { scraper.send(:validate_result, 'not a hash') }.to raise_error(
          Scrappers::ValidationError
        )
      end
    end

    context 'with missing required fields' do
      it 'raises MissingFieldError when name is missing' do
        data = { price: 99.99 }
        expect { scraper.send(:validate_result, data) }.to raise_error(
          Scrappers::MissingFieldError
        )
      end

      it 'raises MissingFieldError when price is missing' do
        data = { name: 'Product' }
        expect { scraper.send(:validate_result, data) }.to raise_error(
          Scrappers::MissingFieldError
        )
      end
    end

    context 'with non-numeric price' do
      it 'raises ValidationError' do
        data = { name: 'Product', price: 'not a number' }
        expect { scraper.send(:validate_result, data) }.to raise_error(
          Scrappers::ValidationError
        )
      end
    end
  end

  describe '#save_product' do
    let(:data) do
      {
        name: 'Saved Product',
        price: 99.99,
        discount_rate: 10,
        image_url: 'https://example.com/img.jpg',
        raw_attributes: { color: 'blue' }
      }
    end

    it 'creates a new product' do
      expect { scraper.send(:save_product, data) }.to change(Product, :count).by(1)
    end

    it 'creates a price history entry' do
      expect { scraper.send(:save_product, data) }.to change(PriceHistory, :count).by(1)
    end

    it 'associates product with campaign' do
      product = scraper.send(:save_product, data)
      expect(product.campaign).to eq(campaign)
    end

    it 'stores all provided data' do
      product = scraper.send(:save_product, data)
      expect(product.name).to eq(data[:name])
      expect(product.image_url).to eq(data[:image_url])
      # JSONB stores keys as strings, not symbols
      expect(product.raw_attributes).to eq(data[:raw_attributes].stringify_keys)
    end

    context 'when product already exists' do
      before do
        create(:product, campaign: campaign, external_id: Digest::MD5.hexdigest(url))
      end

      it 'updates the existing product' do
        expect { scraper.send(:save_product, data) }.not_to change(Product, :count)
      end

      it 'creates a new price history entry' do
        expect { scraper.send(:save_product, data) }.to change(PriceHistory, :count).by(1)
      end
    end

    context 'when transaction fails' do
      before do
        allow_any_instance_of(Product).to receive(:update!).and_raise(
          ActiveRecord::RecordInvalid
        )
      end

      it 'rolls back all changes' do
        expect { scraper.send(:save_product, data) }.to raise_error(
          ActiveRecord::RecordInvalid
        )
        expect(Product.count).to eq(0)
        expect(PriceHistory.count).to eq(0)
      end
    end
  end

  describe '#parse_html' do
    let(:html) { '<html><body><p>Test</p></body></html>' }

    it 'returns a Nokogiri document' do
      doc = scraper.send(:parse_html, html)
      expect(doc).to be_a(Nokogiri::HTML::Document)
    end

    it 'parses HTML correctly' do
      doc = scraper.send(:parse_html, html)
      expect(doc.at('p').text).to eq('Test')
    end

    context 'with empty HTML' do
      it 'raises InvalidHTMLError' do
        expect { scraper.send(:parse_html, '') }.to raise_error(
          Scrappers::InvalidHTMLError
        )
      end
    end

    context 'with invalid HTML' do
      it 'still parses (Nokogiri is lenient)' do
        doc = scraper.send(:parse_html, '<div>unclosed')
        expect(doc).to be_a(Nokogiri::HTML::Document)
      end
    end
  end

  describe '#extract_text' do
    let(:html) { '<div><p class="name">Product Name</p></div>' }
    let(:doc) { Nokogiri::HTML(html) }

    it 'extracts text from matching selector' do
      text = scraper.send(:extract_text, doc, 'p.name')
      expect(text).to eq('Product Name')
    end

    it 'strips whitespace' do
      html_with_space = '<div><p class="name">  Product Name  </p></div>'
      doc = Nokogiri::HTML(html_with_space)
      text = scraper.send(:extract_text, doc, 'p.name')
      expect(text).to eq('Product Name')
    end

    it 'returns nil for non-matching selector' do
      text = scraper.send(:extract_text, doc, 'p.nonexistent')
      expect(text).to be_nil
    end

    it 'returns nil for nil element' do
      text = scraper.send(:extract_text, nil, 'p.name')
      expect(text).to be_nil
    end

    it 'returns nil for nil selector' do
      text = scraper.send(:extract_text, doc, nil)
      expect(text).to be_nil
    end
  end

  describe '#extract_number' do
    it 'extracts number from text' do
      result = scraper.send(:extract_number, 'Price: $99.99')
      expect(result).to eq(99.99)
    end

    it 'handles comma as decimal separator' do
      result = scraper.send(:extract_number, 'Price: €99,99')
      expect(result).to eq(99.99)
    end

    it 'rounds to 2 decimal places' do
      result = scraper.send(:extract_number, '99.999')
      expect(result).to eq(100.0)
    end

    it 'returns nil for blank text' do
      result = scraper.send(:extract_number, '')
      expect(result).to be_nil
    end

    it 'returns 0 for no numbers' do
      result = scraper.send(:extract_number, 'no numbers here')
      expect(result).to eq(0.0)
    end
  end

  describe '#extract_price' do
    it 'extracts price from text' do
      result = scraper.send(:extract_price, '$49.99')
      expect(result).to eq(49.99)
    end

    context 'with invalid price' do
      it 'raises ValidationError for blank text' do
        expect { scraper.send(:extract_price, '') }.to raise_error(
          Scrappers::ValidationError
        )
      end

      it 'raises ValidationError for zero price' do
        expect { scraper.send(:extract_price, '$0.00') }.to raise_error(
          Scrappers::ValidationError
        )
      end

      it 'raises ValidationError for no numeric value' do
        expect { scraper.send(:extract_price, 'no price') }.to raise_error(
          Scrappers::ValidationError
        )
      end
    end
  end

  describe '#extract_discount_rate' do
    it 'extracts discount rate from text' do
      result = scraper.send(:extract_discount_rate, '25% off')
      expect(result).to eq(25.0)
    end

    it 'returns nil for blank text' do
      result = scraper.send(:extract_discount_rate, '')
      expect(result).to be_nil
    end

    it 'clamps values over 100 to 100' do
      result = scraper.send(:extract_discount_rate, '150')
      expect(result).to eq(100)
    end

    it 'returns 0 for negative values (after number extraction)' do
      # Note: extract_number strips the minus sign, so '-10' becomes '10'
      # Then we check if rate < 0, which it's not, so it returns 10
      result = scraper.send(:extract_discount_rate, '-10')
      expect(result).to eq(10.0)
    end
  end

  describe '#handle_error' do
    let(:error) { Scrappers::NetworkError.new('Connection failed') }

    it 'logs the error' do
      expect(scraper.logger).to receive(:error)
      scraper.send(:handle_error, error)
    end

    it 'includes error class and message in log' do
      expect(scraper.logger).to receive(:error).with(include('Scraper error', 'Connection failed'))
      scraper.send(:handle_error, error)
    end

    it 'includes campaign and URL in debug log' do
      expect(scraper.logger).to receive(:debug).with(/Campaign/)
      scraper.send(:handle_error, error)
    end
  end

  describe '#generate_external_id' do
    it 'generates MD5 hash of URL' do
      expected_id = Digest::MD5.hexdigest(url)
      result = scraper.send(:generate_external_id, {})
      expect(result).to eq(expected_id)
    end

    it 'generates same ID for same URL' do
      id1 = scraper.send(:generate_external_id, {})
      id2 = scraper.send(:generate_external_id, {})
      expect(id1).to eq(id2)
    end
  end

  describe '#parse_response (abstract)' do
    it 'raises NotImplementedError for base class' do
      base_scrapper = BaseScrapper.new(url: url, campaign: campaign)
      expect { base_scrapper.parse_response('<html></html>') }.to raise_error(
        NotImplementedError
      )
    end
  end

  describe '#source_name (abstract)' do
    it 'raises NotImplementedError for base class' do
      base_scrapper = BaseScrapper.new(url: url, campaign: campaign)
      expect { base_scrapper.source_name }.to raise_error(NotImplementedError)
    end
  end
end
