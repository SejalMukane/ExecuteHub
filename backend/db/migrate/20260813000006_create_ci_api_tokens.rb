class CreateCiApiTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :ci_api_tokens do |t|
      t.bigint :project_id, null: false
      t.string :name
      # A short non-secret prefix shown in the UI so users can tell tokens apart.
      t.string :token_prefix
      # SHA-256 digest of the full token. The raw token is stored NOWHERE.
      t.string :token_digest, null: false
      t.datetime :last_used_at
      # Present once the token is revoked / rotated away.
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :ci_api_tokens, :project_id
    add_index :ci_api_tokens, :token_digest, unique: true
    add_foreign_key :ci_api_tokens, :projects
  end
end