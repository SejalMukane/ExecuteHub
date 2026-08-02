class CreateWorkerHeartbeats < ActiveRecord::Migration[8.1]
  def change
    create_table :worker_heartbeats do |t|
      t.string :worker_name, null: false
      t.string :status, null: false, default: "idle"
      t.datetime :last_seen_at
      t.bigint :current_job_id
      t.float :cpu_usage
      t.float :memory_usage
      t.integer :execution_count, null: false, default: 0

      t.timestamps
    end

    add_index :worker_heartbeats, :worker_name, unique: true
    add_index :worker_heartbeats, :status
    add_index :worker_heartbeats, :last_seen_at
    add_foreign_key :worker_heartbeats, :jobs, column: :current_job_id
  end
end
