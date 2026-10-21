class AddUniquePairIndexToFriendships < ActiveRecord::Migration[8.1]
  def up
    # Nettoyage préalable, sinon l'index unique ne peut pas être créé :
    # pour chaque paire d'utilisateurs (dans un sens ou l'autre), on garde une seule ligne,
    # en privilégiant accepted > pending > rejected, puis la plus ancienne.
    execute <<~SQL
      DELETE FROM friendships WHERE requester_id = receiver_id;

      DELETE FROM friendships WHERE id IN (
        SELECT id FROM (
          SELECT id, ROW_NUMBER() OVER (
            PARTITION BY LEAST(requester_id, receiver_id), GREATEST(requester_id, receiver_id)
            ORDER BY CASE status WHEN 'accepted' THEN 0 WHEN 'pending' THEN 1 ELSE 2 END, created_at
          ) AS rank
          FROM friendships
        ) ranked
        WHERE rank > 1
      );
    SQL

    # Une seule amitié par paire, quel que soit le sens (A→B et B→A comptent pour la même paire)
    add_index :friendships, "LEAST(requester_id, receiver_id), GREATEST(requester_id, receiver_id)",
              unique: true, name: "index_friendships_on_user_pair"
    add_check_constraint :friendships, "requester_id <> receiver_id", name: "friendships_not_self"
  end

  def down
    remove_check_constraint :friendships, name: "friendships_not_self"
    remove_index :friendships, name: "index_friendships_on_user_pair"
  end
end
