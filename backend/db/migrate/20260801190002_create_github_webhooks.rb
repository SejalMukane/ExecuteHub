class CreateGithubWebhooks < ActiveRecord::Migration[8.1]
  def change
    create_table :github_webhooks do |t|
      t.references :github_repository, null: false, foreign_key: true
      t.bigint :github_webhook_id
      t.string :slug, null: false
      t.string :url
      t.string :secret
      t.string :events
      t.boolean :active, default: true, null: false
      t.datetime :last_delivery_at

      t.timestamps
    end
    add_index :github_webhooks, :slug, unique: true
    add_index :github_webhooks, :github_webhook_id, unique: true
  end
end
