namespace :events do
  desc "Supprime les vieux events non-reminder"
  task clean: :environment do
    deleted = Event.where("date < ?", Date.today)
                   .where(reminder: false)
                   .where.not(url: nil)
                   .destroy_all
    puts "#{deleted.count} events supprimés"
  end
end
