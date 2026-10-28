class AddProductsOnItems < ActiveRecord::Migration[8.1]
  def change
    add_reference :items, :product, foreign_key: { on_delete: :nullify }
  end
end
