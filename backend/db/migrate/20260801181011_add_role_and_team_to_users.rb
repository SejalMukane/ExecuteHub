class AddRoleAndTeamToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :role, :string, default: "developer", null: false
    add_reference :users, :team, foreign_key: true
  end
end
