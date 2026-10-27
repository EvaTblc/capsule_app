FactoryBot.define do
  factory :user do
    email { Faker::Internet.unique.email }
    password { "password123" }
    password_confirmation { "password123" }

    trait :admin do
      role { "admin" }
    end

    trait :premium do
      role { "premium" }
    end
  end
end
