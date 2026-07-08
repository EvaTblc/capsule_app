FactoryBot.define do
  factory :item do
    title { Faker::Book.title }
    condition { "Bon état" }
    association :collection
    association :item_detailable, factory: :book_detail
    item_type { "BookDetail" }
    item_detailable_type { "BookDetail" }
  end
end
