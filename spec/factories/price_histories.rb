FactoryBot.define do
  factory :price_history do
    product
    price { Faker::Commerce.price(range: 100..10000) }
    discount_rate { rand(0..50) }
    recorded_at { Time.current }
  end
end
