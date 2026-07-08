FactoryBot.define do
  factory :collection do
    title { Faker::Book.title }
    category { "books" }
  end
end
