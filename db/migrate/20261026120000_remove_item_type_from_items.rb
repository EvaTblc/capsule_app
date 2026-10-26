class RemoveItemTypeFromItems < ActiveRecord::Migration[8.1]
  # items.item_type répétait item_detailable_type (le type du détail polymorphe) : deux sources de vérité
  # qui pouvaient diverger. Seul item_detailable_type reste ; Item#item_type le lit.
  def up
    remove_column :items, :item_type
  end

  def down
    add_column :items, :item_type, :string
    execute "UPDATE items SET item_type = item_detailable_type"
  end
end
