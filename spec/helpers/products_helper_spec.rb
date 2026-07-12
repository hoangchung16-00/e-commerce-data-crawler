require 'rails_helper'

RSpec.describe ProductsHelper, type: :helper do
  describe '#safe_product_url' do
    it 'returns valid http URL' do
      url = 'http://example.com/product'
      result = helper.safe_product_url(url)
      expect(result).to eq(url)
    end

    it 'returns valid https URL' do
      url = 'https://example.com/product'
      result = helper.safe_product_url(url)
      expect(result).to eq(url)
    end

    it 'returns nil for blank URL' do
      result = helper.safe_product_url('')
      expect(result).to be_nil
    end

    it 'returns nil for nil URL' do
      result = helper.safe_product_url(nil)
      expect(result).to be_nil
    end

    it 'returns nil for invalid URL format' do
      result = helper.safe_product_url('not a url')
      expect(result).to be_nil
    end

    it 'returns nil for non-http protocol' do
      url = 'ftp://example.com/file'
      result = helper.safe_product_url(url)
      expect(result).to be_nil
    end

    it 'returns nil for javascript protocol' do
      url = 'javascript:alert("xss")'
      result = helper.safe_product_url(url)
      expect(result).to be_nil
    end
  end
end
