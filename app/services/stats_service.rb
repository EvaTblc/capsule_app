class StatsService
  def self.call(collection)
    hash_conditions = collection.items.group_by(&:condition)

    results = {condition: {}}

    hash_conditions.each do |condition, items|
      results[:condition][condition] = (hash_conditions[condition].length * 100) / collection.items.count
    end

    if collection.category == "video_games"
      vg_items = collection.items.where(item_detailable_type: "VideoGameDetail")
      completed = vg_items.select { |i| i.item_detailable.completed }.count
      results[:completed] = (completed * 100) / vg_items.count
    end

    results

  end
end
