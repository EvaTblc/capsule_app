FactoryBot.define do
  factory :wish do
    title { "Ōkami" }
    association :collection

    # Auteur membre de la collection (la validation author_is_member l'exige à la création)
    trait :by_member do
      transient { member { create(:user) } }
      author { member }
      after(:build) { |wish, ctx| create(:user_collection, user: ctx.member, collection: wish.collection) }
    end
  end
end
