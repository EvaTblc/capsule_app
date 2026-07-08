FactoryBot.define do
  factory :note do
    title { Faker::Lorem.sentence(word_count: 3) }
    comment { Faker::Lorem.paragraph }
    reminder { false }
    association :user
  end
end
