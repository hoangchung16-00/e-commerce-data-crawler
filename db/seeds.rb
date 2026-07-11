# Seed data for e-commerce data crawler
# Run: bin/rails db:seed

# Clear existing data
[ PriceHistory, Product, Campaign, User ].each(&:delete_all)

puts "Seeding database..."

# 1. Create test users
user1 = User.find_or_create_by!(email: "user1@example.com") do |u|
  u.password = "password123"
  u.password_confirmation = "password123"
end

user2 = User.find_or_create_by!(email: "user2@example.com") do |u|
  u.password = "password123"
  u.password_confirmation = "password123"
end

puts "✓ Created #{User.count} users"

# 2. Create campaigns
campaign1 = Campaign.find_or_create_by!(user_id: user1.id, name: "Tiki Laptop Hunt") do |c|
  c.keyword = "laptop"
  c.target_source = "tiki"
  c.frequency = "daily"
  c.status = "active"
end

campaign2 = Campaign.find_or_create_by!(user_id: user1.id, name: "Shopee Phone Deals") do |c|
  c.keyword = "smartphone"
  c.target_source = "shopee"
  c.frequency = "hourly"
  c.status = "active"
end

campaign3 = Campaign.find_or_create_by!(user_id: user2.id, name: "Amazon Electronics") do |c|
  c.keyword = "headphones"
  c.target_source = "amazon"
  c.frequency = "daily"
  c.status = "paused"
end

puts "✓ Created #{Campaign.count} campaigns"

# 3. Create products
products_data = [
  # Tiki products
  {
    campaign: campaign1,
    external_id: "tiki_12345",
    name: "Dell XPS 13 Laptop",
    url: "https://tiki.vn/dell-xps-13",
    image_url: "https://example.com/dell-xps-13.jpg",
    raw_attributes: { color: "silver", ram: "16GB", storage: "512GB SSD" }
  },
  {
    campaign: campaign1,
    external_id: "tiki_12346",
    name: "MacBook Pro 14\"",
    url: "https://tiki.vn/macbook-pro-14",
    image_url: "https://example.com/macbook-pro-14.jpg",
    raw_attributes: { color: "space gray", ram: "8GB", storage: "256GB SSD" }
  },
  # Shopee products
  {
    campaign: campaign2,
    external_id: "shopee_98765",
    name: "iPhone 15 Pro Max",
    url: "https://shopee.vn/iphone-15-pro-max",
    image_url: "https://example.com/iphone-15.jpg",
    raw_attributes: { color: "titanium black", storage: "256GB" }
  },
  {
    campaign: campaign2,
    external_id: "shopee_98766",
    name: "Samsung Galaxy S24",
    url: "https://shopee.vn/samsung-galaxy-s24",
    image_url: "https://example.com/galaxy-s24.jpg",
    raw_attributes: { color: "phantom black", storage: "128GB" }
  },
  # Amazon products
  {
    campaign: campaign3,
    external_id: "amazon_56789",
    name: "Sony WH-1000XM5 Headphones",
    url: "https://amazon.com/sony-headphones",
    image_url: "https://example.com/sony-headphones.jpg",
    raw_attributes: { color: "black", noise_cancellation: "active" }
  },
  {
    campaign: campaign3,
    external_id: "amazon_56790",
    name: "Bose QuietComfort 45",
    url: "https://amazon.com/bose-qc45",
    image_url: "https://example.com/bose-qc45.jpg",
    raw_attributes: { color: "white", noise_cancellation: "active" }
  }
]

products = products_data.map do |data|
  Product.find_or_create_by!(campaign_id: data[:campaign].id, external_id: data[:external_id]) do |p|
    p.name = data[:name]
    p.url = data[:url]
    p.image_url = data[:image_url]
    p.raw_attributes = data[:raw_attributes]
  end
end

puts "✓ Created #{Product.count} products"

# 4. Create price histories (simulate price tracking over 30 days)
base_prices = {
  "tiki_12345" => 25_000_000,  # Dell XPS 13 in VND
  "tiki_12346" => 35_000_000,  # MacBook Pro in VND
  "shopee_98765" => 24_000_000, # iPhone 15 Pro Max in VND
  "shopee_98766" => 18_000_000, # Galaxy S24 in VND
  "amazon_56789" => 349_000,    # Sony headphones in USD
  "amazon_56790" => 379_000     # Bose headphones in USD
}

products.each do |product|
  base_price = base_prices[product.external_id]

  # Create price history for the last 30 days
  (30.downto(1)).each do |days_ago|
    # Simulate price fluctuations
    price_variation = rand(-10..15).to_f * base_price / 100
    recorded_price = (base_price + price_variation).round(2)
    discount_rate = rand(0..30)

    PriceHistory.find_or_create_by!(
      product_id: product.id,
      recorded_at: days_ago.days.ago.beginning_of_day + rand(0..86400).seconds
    ) do |ph|
      ph.price = recorded_price
      ph.discount_rate = discount_rate
    end
  end
end

puts "✓ Created #{PriceHistory.count} price history records"

puts "\n✅ Seeding completed successfully!"
puts "Test login: user1@example.com / password123"
