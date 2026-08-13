class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.bigint :project_id
      t.bigint :test_run_id
      t.bigint :pipeline_id
      t.string :title, null: false
      t.string :description
      t.string :category, null: false, default: "system"
      t.boolean :read, null: false, default: false

      t.timestamps
    end

    add_index :notifications, [:project_id, :read]
    add_index :notifications, :created_at
    add_index :notifications, :test_run_id
    add_index :notifications, :pipeline_id

    add_foreign_key :notifications, :projects
    add_foreign_key :notifications, :test_runs
    add_foreign_key :notifications, :pipelines
  end
end
