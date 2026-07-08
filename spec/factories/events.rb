FactoryBot.define do
  factory :event do
    title { Faker::Lorem.sentence(word_count: 3) }
    date { Date.today + 3.days }
    address { Faker::Address.full_address }
    reminder { false }
    association :user
  end
end
