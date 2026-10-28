namespace :products do
  desc "Relie les items existants à leurs œuvres du catalogue et retire les données TMDB / Google Books. " \
       "Mode essai par défaut (rien n'est enregistré) ; APPLY=1 pour écrire"
  task backfill: :environment do
    apply = ENV["APPLY"] == "1"
    puts apply ? "Mode réel : les changements sont enregistrés." : "Mode essai : rien n'est enregistré (APPLY=1 pour écrire)."

    results = CatalogBackfill.new(apply: apply).run
    results.each do |r|
      line = "#{r.status.to_s.ljust(9)} ##{r.item.id} #{r.item.item_detailable_type.delete_suffix('Detail').ljust(9)} « #{r.item.title} »"
      line += " → #{r.product.title}" if r.product
      line += " | remplacés : #{r.replaced.join(', ')}" if r.replaced.present?
      line += " | #{r.note}" if r.note
      puts line
    end
    puts "\nBilan : #{results.group_by(&:status).transform_values(&:size).map { |status, count| "#{status} #{count}" }.join(', ')}"
  end
end
