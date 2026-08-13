class CreatePipelines < ActiveRecord::Migration[8.1]
  def change
    create_table :pipelines do |t|
      t.bigint :project_id, null: false
      t.string :name
      t.string :provider, null: false, default: "jenkins"
      t.string :status, null: false, default: "pending"
      t.string :branch
      t.string :commit_sha
      t.string :triggered_by, null: false, default: "jenkins"
      # Stable external identity (`jenkins:<job>:<build>`) used to guarantee
      # idempotent CI triggers — retrying the same Jenkins request must never
      # create a second pipeline.
      t.string :ci_key, null: false

      t.timestamps
    end

    add_index :pipelines, :project_id
    add_index :pipelines, :status
    add_index :pipelines, :ci_key, unique: true
    add_foreign_key :pipelines, :projects
  end
end