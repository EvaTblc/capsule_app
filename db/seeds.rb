# db/seeds.rb
puts "Nettoyage..."
Friendship.destroy_all
Note.destroy_all
Event.destroy_all
UserCollection.destroy_all
Item.destroy_all
Collection.destroy_all
User.where.not(email: "eva@capsule.click").destroy_all

puts "Création du user..."
eva = User.find_or_create_by(email: "eva@capsule.click") do |u|
  u.password = "password123"
  u.password_confirmation = "password123"
end

puts "Création de la collection..."
jv = Collection.create!(title: "Ma ludothèque", category: "video_games")
UserCollection.create!(user: eva, collection: jv, role: "owner")

puts "Création des items..."
[
  { title: "Hollow Knight", platform: "Nintendo Switch", completed: false },
  { title: "Hades", platform: "PC", completed: true },
  { title: "Elden Ring", platform: "PS5", completed: false },
].each do |attrs|
  detail = VideoGameDetail.create!(
    platform: attrs[:platform],
    completed: attrs[:completed]
  )
  Item.create!(
    title: attrs[:title],
    collection: jv,
    item_detailable: detail,
    item_type: "video_game"
  )
end

puts "✅ Done ! #{Item.count} items créés"
