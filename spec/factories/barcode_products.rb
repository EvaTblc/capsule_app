FactoryBot.define do
  factory :barcode_product do
    sequence(:barcode) { |n| (45496000000 + n).to_s.rjust(13, "0") }
    kind { "game" }
    source { "bnf" }
    raw_title { "Pokémon : version diamant / Game freak" }
    fetched_at { Time.current }
  end
end
