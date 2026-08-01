class CreateGithubWebhookDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :github_webhook_deliveries do |t|
      t.references :github_webhook, null: false, foreign_key: true
      t.string :delivery_id
      t.string :event
      t.boolean :signature_valid, default: true, null: false
      t.jsonb :payload
      t.datetime :received_at

      t.timestamps
    end
    add_index :github_webhook_deliveries, :delivery_id
  end
end
