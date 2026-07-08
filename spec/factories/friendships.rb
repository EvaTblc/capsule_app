FactoryBot.define do
  factory :friendship do
    status { "pending" }
    association :requester, factory: :user
    association :receiver, factory: :user
  end
end
