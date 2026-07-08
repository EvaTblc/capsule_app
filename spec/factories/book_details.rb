FactoryBot.define do
  factory :book_detail do
    author { Faker::Book.author }
    isbn { Faker::Code.isbn }
  end
end
