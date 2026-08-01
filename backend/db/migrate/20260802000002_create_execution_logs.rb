class CreateExecutionLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :execution_logs do |t|
      t.references :job, null: false, foreign_key: true
      t.datetime :timestamp, null: false
      t.string :level, null: false, default: "info"
      t.text :message, null: false

      t.timestamps
    end

    add_index :execution_logs, [:job_id, :timestamp]
  end
end
