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
end
