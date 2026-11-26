# Les notes sont remplacées par la liste de souhaits (Wish) : la table disparaît, avec son contenu.
# Le bloc ne sert qu'à recréer la structure en cas de retour arrière (les notes supprimées ne reviennent pas)
class DropNotes < ActiveRecord::Migration[8.1]
  def change
    drop_table :notes do |t|
      t.string :title
      t.text :comment
      t.references :user, null: false, foreign_key: true
      t.boolean :reminder
      t.references :sender, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :collection, foreign_key: true
      t.timestamps
    end
  end
end
