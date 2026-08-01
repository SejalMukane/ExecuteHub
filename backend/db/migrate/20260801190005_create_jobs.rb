class CreateJobs < ActiveRecord::Migration[8.1]
  def change
    create_table :jobs do |t|
      t.references :test_run, null: false, foreign_key: true
      t.string :worker_id
      t.integer :chunk_number, null: false, default: 1
      t.integer :test_count, null: false, default: 0
      t.string :status, null: false, default: "queued"
      t.datetime :started_at
      t.datetime :finished_at
      t.integer :retry_count, null: false, default: 0

      t.timestamps
    end

    add_index :jobs, [:test_run_id, :chunk_number], unique: true
    add_index :jobs, :status
  end
end
