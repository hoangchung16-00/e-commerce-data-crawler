FactoryBot.define do
  factory :product do
    campaign
    external_id { Faker::Internet.unique.slug }
    name { Faker::Commerce.product_name }
    url { Faker::Internet.unique.url }
    image_url { 'https://via.placeholder.com/300x300?text=Product' }
    raw_attributes { { color: 'red', size: 'L' } }
  end
end
