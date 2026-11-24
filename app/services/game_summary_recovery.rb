# Jeux sans aucun résumé (ni français, ni anglais) mais reliés au catalogue : surtout ceux de l'ancien ajout rapide,
# qui perdait le résumé. L'œuvre du catalogue l'a gardé (IGDB) : on le leur rend.
# - œuvre déjà traduite : sa description française est copiée, sans appel à Claude
# - sinon : son résumé anglais est copié sur l'item et TranslationJob le traduit, une fois pour toute l'œuvre
#   (les autres items du même jeu reprendront cette traduction gratuitement)
class GameSummaryRecovery
  Result = Data.define(:item, :status) # status : :copied_french, :to_translate, :no_summary

  def self.candidates
    missing = VideoGameDetail.where(description: [ nil, "" ], summary_en: [ nil, "" ])
    Item.where(item_detailable_type: "VideoGameDetail", item_detailable_id: missing.select(:id))
        .where.not(product_id: nil)
        .includes(:product, :item_detailable)
  end

  # Mode essai par défaut : rien n'est écrit ni mis en file
  def self.run(apply: false)
    candidates.map do |item|
      product = item.product
      detail = item.item_detailable
      summary_en = product.details["summary_en"].presence

      if product.description.present?
        detail.update!(description: product.description, summary_en: summary_en) if apply
        Result.new(item, :copied_french)
      elsif summary_en
        if apply
          detail.update!(summary_en: summary_en)
          TranslationJob.perform_later(item.id)
        end
        Result.new(item, :to_translate)
      else
        Result.new(item, :no_summary) # IGDB n'a pas de résumé pour ce jeu : rien à rendre
      end
    end
  end
end
