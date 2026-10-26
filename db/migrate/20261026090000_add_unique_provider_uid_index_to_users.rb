class AddUniqueProviderUidIndexToUsers < ActiveRecord::Migration[8.1]
  # Un compte Google ne peut être relié qu'à un seul compte Capsule.
  # Index partiel : les comptes e-mail/mot de passe (provider et uid vides) ne sont pas concernés.
  def change
    add_index :users, [ :provider, :uid ], unique: true, where: "provider IS NOT NULL AND uid IS NOT NULL"
  end
end
