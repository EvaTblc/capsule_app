namespace :games do
  desc "Vérifie les jeux avec description anglaise sur l'item, celles sans description mais reliées au catalogue, et celles sans description et sans lien catalogue."
  task summaries_report: :environment do
    details = VideoGameDetail.where(id: Item.where(item_detailable_type: "VideoGameDetail").select(:item_detailable_id))
    puts "Jeux : #{Item.where(item_detailable_type: "VideoGameDetail").count}"
    to_translate = details.where(description: [ nil, "" ]).where.not(summary_en: [ nil, "" ]).count
    puts "1 - Jeux sans résumé FR mais avec résumé EN : #{to_translate}"

    missing = details.where(description: [ nil, "" ], summary_en: [ nil, "" ])
    missing_items = Item.where(item_detailable_type: "VideoGameDetail", item_detailable_id: missing.select(:id))
    puts "2 - Jeux reliés au catalogue : #{missing_items.where.not(product_id: nil).count}"
    puts "3 - Jeux non reliés au catalogue : #{missing_items.where(product_id: nil).count}"
  end

  desc "Rend leur résumé aux jeux qui n'en ont aucun mais sont reliés au catalogue (copie du français de l'œuvre, " \
       "sinon de l'anglais puis traduction). Mode essai par défaut (rien n'est enregistré) ; APPLY=1 pour écrire"
  task recover_summaries: :environment do
    apply = ENV["APPLY"] == "1"
    puts apply ? "Mode réel : les changements sont enregistrés." : "Mode essai : rien n'est enregistré (APPLY=1 pour écrire)."

    labels = { copied_french: "français copié", to_translate: "à traduire", no_summary: "aucun résumé chez IGDB" }
    results = GameSummaryRecovery.run(apply: apply)
    results.each { |result| puts "#{labels[result.status].ljust(23)} ##{result.item.id} « #{result.item.title} »" }
    puts "\nBilan : #{results.map(&:status).tally.map { |status, count| "#{labels[status]} #{count}" }.join(', ').presence || 'rien à faire'}"
    puts "Traductions mises en file : elles se font en arrière-plan, la fiche se rafraîchit toute seule." if apply && results.any? { |result| result.status == :to_translate }
  end
end
