FactoryBot.define do
  factory :product do
    kind { "game" }
    title { "Pokémon Diamant" }
    fetched_at { Time.current }
    sequence(:igdb_id) { |n| n }

    trait :movie do
      kind { "movie" }
      title { "Intouchables" }
      igdb_id { nil }
      sequence(:wikidata_id) { |n| "Q#{n}" }
    end

    trait :book do
      kind { "book" }
      title { "Veiller sur elle" }
      igdb_id { nil }
    end
  end
end
