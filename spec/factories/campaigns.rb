FactoryBot.define do
  factory :campaign do
    user
    name { Faker::Commerce.product_name }
    keyword { Faker::Commerce.product_name }
    target_source { %w[tiki amazon shopee lazada].sample }
    frequency { %w[hourly daily manual].sample }
    status { 'active' }
  end
end
