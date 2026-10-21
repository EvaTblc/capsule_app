class AddIntegrityConstraints < ActiveRecord::Migration[8.1]
  def up
    # 1. Rendre les données existantes conformes, sinon les contraintes ne peuvent pas être posées
    execute <<~SQL
      UPDATE items       SET title = 'Sans titre' WHERE title IS NULL OR btrim(title) = '';
      UPDATE collections SET title = 'Sans titre' WHERE title IS NULL OR btrim(title) = '';
      UPDATE collections SET category = 'other' WHERE category IS NULL;
      UPDATE user_collections SET role = 'member' WHERE role IS NULL OR role NOT IN ('owner', 'member');

      -- Adhésions en double : on garde le rôle de propriétaire s'il existe, sinon la plus ancienne
      DELETE FROM user_collections WHERE id IN (
        SELECT id FROM (
          SELECT id, ROW_NUMBER() OVER (
            PARTITION BY user_id, collection_id ORDER BY (role = 'owner') DESC, created_at, id
          ) AS rank
          FROM user_collections
        ) ranked
        WHERE rank > 1
      );

      -- Événements importés en double (même lien pour le même utilisateur) : on garde le plus ancien
      DELETE FROM events WHERE id IN (
        SELECT id FROM (
          SELECT id, ROW_NUMBER() OVER (PARTITION BY user_id, url ORDER BY created_at, id) AS rank
          FROM events
          WHERE url IS NOT NULL
        ) ranked
        WHERE rank > 1
      );

      -- Expéditeurs supprimés : la clé étrangère refuserait ces lignes
      UPDATE notes  SET sender_id = NULL WHERE sender_id IS NOT NULL AND sender_id NOT IN (SELECT id FROM users);
      UPDATE events SET sender_id = NULL WHERE sender_id IS NOT NULL AND sender_id NOT IN (SELECT id FROM users);

      -- Jetons d'invitation absents ou en double : nouveau jeton
      UPDATE collections SET invite_token = replace(gen_random_uuid()::text, '-', '')
      WHERE invite_token IS NULL OR id IN (
        SELECT id FROM (
          SELECT id, ROW_NUMBER() OVER (PARTITION BY invite_token ORDER BY id) AS rank FROM collections
        ) ranked
        WHERE rank > 1
      );
    SQL

    # 2. Unicité : protège contre les doubles clics et les requêtes simultanées
    #    (les index composites remplacent les index simples sur user_id, devenus redondants)
    remove_index :user_collections, :user_id
    add_index :user_collections, [ :user_id, :collection_id ], unique: true
    remove_index :events, :user_id
    add_index :events, [ :user_id, :url ], unique: true # plusieurs url NULL restent possibles (événements saisis à la main)
    add_index :collections, :invite_token, unique: true

    # 3. Expéditeurs : même type que users.id, index, et clé étrangère qui vide le champ si l'expéditeur disparaît
    change_column :notes, :sender_id, :bigint
    change_column :events, :sender_id, :bigint
    add_index :notes, :sender_id
    add_index :events, :sender_id
    add_foreign_key :notes, :users, column: :sender_id, on_delete: :nullify
    add_foreign_key :events, :users, column: :sender_id, on_delete: :nullify

    # 4. Champs obligatoires, garantis même hors des validations Rails (update_columns, insert_all, console...)
    change_column_null :items, :title, false
    change_column_null :collections, :title, false
    change_column_null :collections, :category, false
    change_column_null :collections, :invite_token, false
    add_check_constraint :user_collections, "role IN ('owner', 'member')", name: "user_collections_role_valid"
  end

  def down
    remove_check_constraint :user_collections, name: "user_collections_role_valid"
    change_column_null :collections, :invite_token, true
    change_column_null :collections, :category, true
    change_column_null :collections, :title, true
    change_column_null :items, :title, true

    remove_foreign_key :events, column: :sender_id
    remove_foreign_key :notes, column: :sender_id
    remove_index :events, :sender_id
    remove_index :notes, :sender_id
    change_column :events, :sender_id, :integer
    change_column :notes, :sender_id, :integer

    remove_index :collections, :invite_token
    remove_index :events, [ :user_id, :url ]
    add_index :events, :user_id
    remove_index :user_collections, [ :user_id, :collection_id ]
    add_index :user_collections, :user_id
    # Le nettoyage des données (doublons supprimés, titres « Sans titre ») n'est pas annulé
  end
end
