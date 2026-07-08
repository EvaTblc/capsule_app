FactoryBot.define do
  factory :user_collection do
    role { "owner" }
    association :user
    association :collection
  end
end
