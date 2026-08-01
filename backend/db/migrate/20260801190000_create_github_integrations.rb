class CreateGithubIntegrations < ActiveRecord::Migration[8.1]
  def change
    create_table :github_integrations do |t|
      t.references :user, null: false, foreign_key: true
      t.bigint :github_user_id
      t.string :github_login
      t.string :access_token
      t.string :scope

      t.timestamps
    end
    add_index :github_integrations, :github_user_id
  end
end
