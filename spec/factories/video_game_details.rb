# spec/factories/video_game_details.rb
FactoryBot.define do
  factory :video_game_detail do
    platform { "Nintendo Switch" }
    completed { false }
  end
end
