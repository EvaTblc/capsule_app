class AddRoleToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :role, :string, null: false, default: "free"
    add_check_constraint :users, "role IN ('admin', 'premium', 'free')", name: "users_role_valid"
  end
end
